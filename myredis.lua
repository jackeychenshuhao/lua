--   自动添加访问IP高频率到nginx黑名单，缓存至Redis

-- 	 redis手动添加IP个数 :
--   redis-cli SADD count_10.1.30.245 3
--
--   删除redis key:
--   redis-cli SREM count_10.1.30.245 3
--
-- 	 依赖包下载 requires lua-resty-redis from:
--   https://github.com/agentzh/lua-resty-redis
--
--   引入lua-resty-redis包
--   lua_package_path "/etc/nginx/lua/?.lua;;";
--
--   在需要控制访问的站点location段中加入访问控制代码
--   access_by_lua_file /etc/nginx/lua/myredis.lua;

--禁止时间
ip_bind_time = 15
--禁止间隔
ip_time_out = 15
--禁止的个数
connect_count = 3
-- redis服务端地址
local redis_host = "192.168.31.251"
--redis 端口
local redis_port = "6379"
local redis_password = "jackey"

local redis = require "resty.redis"
local cache = redis.new()
local ok , err = cache.connect(cache,redis_host,redis_port)
cache:set_timeout(6000)

-- 连接不需要密码的Redis，打开此段
--if not ok then
--  ngx.log(ngx.ERR, "Can not connect to redis：" .. err);
--  os.exit(0);
--  io.read();
--else
--	  ok, err = cache:set("jackey", "is a good man")
--end

--
--

-- 连接需要有密码的Redis，注释此段
if ok ~= nil then
    local res, err = cache:auth(redis_password)
    if res ~= nil then
       ok, err = cache:set("jackey", "is a good man")
    else
        ngx.log(ngx.ERR,"Redis auth failed:"..err);
	os.exit(0);
	io.read();
    end
else
    ngx.log(ngx.ERR,"Can not connect to redis："..err);
    os.exit(0);
    io.read();
end

-- 
--

-- 获取当前Redis缓存 IP判断值是否为1，则拒绝访问
is_bind , err = cache:get("bind_"..ngx.var.remote_addr)
if is_bind == 1 then
	return ngx.exit(ngx.HTTP_FORBIDDEN)
end

-- 获取访问IP开始时间，访问次数
start_time , err = cache:get("time_"..ngx.var.remote_addr)
ip_count , err = cache:get("count_"..ngx.var.remote_addr)

-- 初始访问IP或者大于禁止间隔时间，重新设置时间，访问次数
if start_time == ngx.null or os.time() - start_time > ip_time_out then
	res , err = cache:set("time_"..ngx.var.remote_addr , os.time())
	res , err = cache:set("count_"..ngx.var.remote_addr , 1)
else

-- 不超过禁止间隔时间，递增访问次数
	ip_count = ip_count + 1
	res , err = cache:incr("count_"..ngx.var.remote_addr)
	
-- 当访问次数大于设置的次数时，设置IP判断值为1，缓存时间，并拒绝访问
  if ip_count >= connect_count then
	res , err = cache:set("bind_"..ngx.var.remote_addr,1)
    res , err = cache:expire("bind_",ip_bind_time)
    ngx.log(ngx.ERR, "Banned IP detected and refused access: " .. ngx.var.remote_addr);
    return ngx.exit(ngx.HTTP_FORBIDDEN);
  end
end

-- 关闭连接
local ok, err = cache:close()