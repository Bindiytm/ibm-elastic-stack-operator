-- Licensed Materials - Property of IBM
-- 5737-E67
-- @ Copyright IBM Corporation 2016, 2020. All Rights Reserved.
-- US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.

local PIM = {}
PIM.__index = PIM

local Util = require "rbac.util"

function PIM.new(old_obj)
    local new_obj = old_obj or {}
    setmetatable(new_obj, PIM)
    return new_obj
end

local cjson = require "cjson"
local http = require "lib.resty.http"

function PIM:query_user_role(token, uid)
    local httpc = http.new()
    -- curl -k --header "Authorization: Bearer ${ACCESS_TOKEN}" https://platform-identity-management.ibm-common-services.svc.cluster.local:4500/identity/api/v1/users/user2/getHighestRole
    local res, err = httpc:request_uri("https://platform-identity-management.{{ .Release.Namespace }}.svc."..self.cluster_domain..":4500/identity/api/v1/users/" .. uid .. "/getHighestRole", {
        method = "GET",
        ssl_verify = false,
        headers = {
          ["Content-Type"] = "application/json",
          ["Authorization"] = "Bearer ".. token
        },
        ssl_verify = false
    })

    if not res then
        ngx.log(ngx.ERR, "Failed to request user role due to ",err)
        return nil, exit_401()
    end

    if (res.body == "" or res.body == nil) then
        ngx.log(ngx.ERR, "Empty response body")
        return nil, exit_401()
    end

    local role_id = tostring(res.body)
    ngx.log(ngx.INFO, "user role=", role_id)

    return role_id
end

function PIM:query_user_namespaces(token, uid)
    local httpc = http.new()
    res, err = httpc:request_uri("https://platform-identity-management.{{ .Release.Namespace }}.svc."..self.cluster_domain..":4500/identity/api/v1/users/" .. uid .. "/getTeamResources", {
        method = "GET",
        ssl_verify = false,
        headers = {
          ["Content-Type"] = "application/json",
          ["Authorization"] = "Bearer ".. token
        },
        query = {
            ["resourceType"] = "namespace"
        },
        ssl_verify = false
    })

    if not res then
        ngx.log(ngx.ERR, "Failed to request user's authorized namespaces due to ",err)
        return nil, exit_401()
    end

    if (res.body == "" or res.body == nil) then
        ngx.log(ngx.ERR, "Empty response body")
        return nil, exit_401()
    end

    local x = tostring(res.body)

    ngx.log(ngx.INFO, "raw_namespaces=",x)

    local namespaces = {}
    local num_namespaces = 0

    for i, entry in ipairs(cjson.decode(x)) do
        ngx.log(ngx.DEBUG, "namespaceId=",entry.namespaceId, ",crn=", entry.crn)
        namespaces[entry.namespaceId] = entry.crn
        num_namespaces = num_namespaces + 1
    end

    ngx.log(ngx.INFO, "num_namespaces=", num_namespaces, ",namespaces=", Util.keys_to_string(namespaces))
    return num_namespaces, namespaces
end

return PIM
