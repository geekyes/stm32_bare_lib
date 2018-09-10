# 自己目前的解决方案是在命令参数 -ex # 里面添加命令，这种是个好办法，
#     脚本真是好东西。
target extended-remote localhost:3333
monitor  arm semihosting enable
set remotetimeout 1000
set arm force-mode thumb
load 
