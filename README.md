# workweixinrobot
## ORACLE PL/SQL workweixin's robot msg-通过ORACLE-PL/SQL发送企业微信群聊机器人消息
## 基于ORACLE数据库自带的UTL_HTTP包发送企业微信群聊机器人消息，封装成可简易使用的函数 
#
## 使用方法： 
### 1.配置ACL授权，允许数据库访问企业微信API的地址 
### 2.在ORACLE数据库中编译该项目中的对象
### 3.执行例子
#
## 关于如何创建群聊机器人及获得webhook-key的方法： 
### 1.打开手机端企业微信客户端，打开一个群（不支持外部群） 
### 2.点击右上角两个人头的图标 
### 3.点击群机器人 
### 4.点击右上角添加 
### 5.输入机器人名字，点击添加按钮 
### 6.返回查看机器人，得到webhook地址中“key=” 后的字符串