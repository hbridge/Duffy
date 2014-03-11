Model Server.

#################################################################
Usage:

start server: torch server.lua
run client: python client.py

#################################################################
requirements:

torch with libzmq
python wiht pyzmq

#################################################################
Server outputs:

$ torch server.lua
Unable to connect X11 server (continuing with -nographics)
initializing zmq
socket initalized: tcp://*:13373
socket initalized: tcp://*:13374
command received:
{
  cmd : init
  model : model2.mat
}
initializing model model2.mat
command received:
{
  cmd : process
  images :
    {
      1 : img1.jpg
      2 : img2.jpg
    }
}
processing images:
{
  1 : img1.jpg
  2 : img2.jpg
}

#################################################################
Client outputs:

$ python client.py
{'status': 'ok', 'model': 'model2.mat', 'cmd': 'init'}
{'status': 'ok', 'images': [{'answers': 43, 'filename': 'img1.jpg'}, {'answers': 44, 'filename': 'img2.jpg'}], 'cmd': 'process'}
