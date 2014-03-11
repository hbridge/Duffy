require 'libluazmq'
local here = paths.dirname(paths.thisfile())..'/'
dofile(here..'json.lua')

local function create_socket(type, port, z)
   local s = z:socket(type)
   local bind = 'tcp://*:'..port
   if not s:bind(bind) then error('failed to bind to '..bind) end
   print('socket initalized: '..bind)
   return s
end

local function execute_command(cmd)
   if cmd.cmd == 'init' then
      print('initializing model '..cmd.model)
      cmd.status = 'ok'
   elseif cmd.cmd == 'process' then
      print('processing images:')
      print(cmd.images)
      cmd.status = 'ok'
      -- insert dummy answers to original list of images
      for i = 1,#cmd.images do
	 cmd.images[i] = { filename=cmd.images[i], answers=42+i }
      end
   else
      print('command not found ')
      print(cmd)
      cmd.status = 'error'
   end
   return cmd
end

print('initializing zmq')
local z = zmq.init(1)
local s = create_socket(zmq.PUSH, 13373, z)
local r = create_socket(zmq.PULL, 13374, z)

-- server loop
while true do
   local cmd = r:recv()
   if cmd then
      cmd = Json.Decode(cmd)
      print('command received: ')
      print(cmd)
      local answer = execute_command(cmd)
      s:send(Json.Encode(answer))
   end
end
