-- 通过 UMC 对进入网关的请求进行身份认证和权限校验。
local core = require("apisix.core")
local http = require("resty.http")

local ngx = ngx
local ipairs = ipairs

local schema = {
    type = "object",
    properties = {
        uri = {type = "string"},
        ssl_verify = {type = "boolean", default = true},
        timeout = {type = "integer", minimum = 1, maximum = 60000, default = 3000},
        keepalive = {type = "boolean", default = true},
        keepalive_timeout = {type = "integer", minimum = 1000, default = 60000},
        keepalive_pool = {type = "integer", minimum = 1, default = 100},
        allow_degradation = {type = "boolean", default = false},
        status_on_error = {type = "integer", minimum = 200, maximum = 599, default = 503},
        upstream_headers = {
            type = "array",
            default = {},
            items = {type = "string"},
        },
        client_headers = {
            type = "array",
            default = {},
            items = {type = "string"},
        },
    },
    required = {"uri"},
}

local _M = {
    version = 0.1,
    priority = 2003,
    name = "umc-auth",
    schema = schema,
}

function _M.check_schema(conf)
    core.utils.check_https({"uri"}, conf, _M.name)
    core.utils.check_tls_bool({"ssl_verify"}, conf, _M.name)
    return core.schema.check(schema, conf)
end

local function build_auth_uri(conf, router, method, gateway_prefix)
    local separator = conf.uri:find("?", 1, true) and "&" or "?"
    local query = ngx.encode_args({
        router = router,
        method = method:lower(),
        gateway_prefix = gateway_prefix,
    })

    return conf.uri .. separator .. query
end

function _M.access(conf, ctx)
    -- ctx.var.uri 是规范化后的原始请求路径，不包含查询参数。
    local request_path = ctx.var.uri

    -- 一段前缀，或者以斜杠结尾的两段前缀，由 APISIX 直接响应。
    local is_one_level_prefix = request_path:match("^/[^/]+/?$")
    local is_two_level_prefix = request_path:match("^/[^/]+/[^/]+/$")
    if is_one_level_prefix or is_two_level_prefix then
        core.response.set_header("Content-Type", "text/plain; charset=utf-8")
        return 200, "hello world"
    end

    local gateway_prefix, router = request_path:match("^/([^/]+)(/.*)$")
    if not gateway_prefix then
        core.log.warn("cannot extract gateway-prefix from request path: ", request_path)
        return 400, "missing gateway-prefix"
    end

    -- 健康检查继续转发到下游服务，但跳过 UMC 权限校验。
    if router:match("/health/?$") then
        return
    end

    local method = core.request.get_method()
    local auth_uri = build_auth_uri(conf, router, method, gateway_prefix)
    local params = {
        method = "GET",
        ssl_verify = conf.ssl_verify,
        keepalive = conf.keepalive,
        headers = {
            ["X-Forwarded-Proto"] = core.request.get_scheme(ctx),
            ["X-Forwarded-Method"] = method,
            ["X-Forwarded-Host"] = core.request.get_host(ctx),
            ["X-Forwarded-Uri"] = ctx.var.request_uri,
            ["X-Forwarded-For"] = core.request.get_remote_client_ip(ctx),
            Cookie = core.request.header(ctx, "Cookie"),
        },
    }

    if conf.keepalive then
        params.keepalive_timeout = conf.keepalive_timeout
        params.keepalive_pool = conf.keepalive_pool
    end

    local httpc = http.new()
    httpc:set_timeout(conf.timeout)
    local res, err = httpc:request_uri(auth_uri, params)
    if not res then
        if conf.allow_degradation then
            return
        end
        core.log.warn("failed to request UMC authorization service: ", err)
        return conf.status_on_error
    end

    if res.status ~= 200 then
        for _, header in ipairs(conf.client_headers) do
            core.response.set_header(header, res.headers[header])
        end
        return res.status, res.body
    end

    for _, header in ipairs(conf.upstream_headers) do
        core.request.set_header(ctx, header, res.headers[header])
    end
end

return _M
