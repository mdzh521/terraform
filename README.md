# 基础设施及代码--Terraform
## 目录结构

```
# tree 
.
├── README.md
├── ali
│   ├── env
│   │   ├── network
│   │   │   ├── main.tf
│   │   │   ├── varable.tf
│   │   │   └── version.tf
│   │   └── service
│   │       ├── main.tf
│   │       ├── nginx.tf
│   │       ├── varable.tf
│   │       └── version.tf
│   └── module
│       ├── ecs
│       │   └── main.tf
│       ├── nat
│       │   └── main.tf
│       ├── secgroup
│       │   └── main.tf
│       ├── vpc
│       │   └── main.tf
│       └── vswitch
│           └── main.tf
├── aws
│   ├── env
│   │   ├── network
│   │   │   ├── main.tf
│   │   │   ├── varable.tf
│   │   │   └── version.tf
│   │   └── server
│   │       ├── main.tf
│   │       ├── mysql.tf
│   │       ├── varable.tf
│   │       └── version.tf
│   └── module
│       ├── common
│       │   ├── internet_gateway
│       │   │   └── main.tf
│       │   ├── nat
│       │   │   └── main.tf
│       │   ├── route
│       │   │   └── main.tf
│       │   ├── security_group
│       │   │   └── main.tf
│       │   ├── subnet
│       │   │   └── main.tf
│       │   └── vpc
│       │       └── main.tf
│       └── server
│           └── nginx
│               └── main.tf
└── docker
    ├── README.md
    ├── network
    │   ├── main.tf
    │   └── versions.tf
    └── server
        ├── jenkins.tf
        ├── main.tf
        └── versions.tf
```

## 基础命令展示
### terraform
基础设施建设

### 初始化仓库
terraform init

### 预览执行内容
terraform plan

### 执行计划
terraform apply

## Terraform 语法
<!-- https://registry.terraform.io/browse/providers 通过此链接可以查看官方验证的方法 -->
<summary>https://registry.terraform.io/browse/providers 通过此链接可以查看官方验证的方法</summary>

### 1. provider
terraform 是通过provider 来维护基础设施，使用provider来和云供应商提供的API进行交互

### 2. resource
Resource 资源来自 Provider，是 Terraform 中最重要的元素，每个资源块描述一个或多个基础对象，例如网络、计算实例或更高级别的组件，例如 DNS 记录。

### 3. datasource
提供资源的数据，可以通过参数过滤数据并且提供给其他模块进行应用，使用 'data' 块声明

### 4. variable
变量，可以通过自定义的形式传入变量值，变量分为多种类型，string，number，bool，list(), set(), map(), object(), tuple()

### 5. locals
本地定义变量，可以定义多重变量

### 6. output
output可以打印已定义的变量，并且可以公开信息以供其他 Terraform 配置使用，输出值类似于编程语言中的返回值。

### 7. module
模块是一种可重用现有代码的方法，以此来减少基础设施组件开发的代码量，加强了代码可读性。module 是一个或多个 *.tf 文件的集合，以此来组成的目录
可以通过命令查看已存在的模块，或者通过远程仓库下载模块 
terraform get <模块地址>
terraform graph 查看模块

## Terraform 表达式
<summary>terraform 调试工具 console 调用方法</summary>

``````
terraform console
``````

### 条件表达式
condition ? true_val : false_val
condition 条件 （返回值为 true/false）
true_val 条件为 true 的值
false_val 条件为 false 的值

### for表达式
借助for表达式可以对数据进行处理，生成新的数据对象
[for index, var in object: "${index}=${var}"]

### splat表达式
splat 表达式提供了一种更简洁的方式，来表达可以用for表达式执行常见操作。

变量内容
```
vsw_spec = [{
    "name" = "prod-redis-01",
    "cidr" = "10.10.10.1"
},{
    "name" = "prod-redis-02",
    "cidr" = "10.10.10.2"
}]
```
变量调用方式
var.vsw_spec[*].name


### Provisioners
用于在本地计算机或远程计算机上执行某些自定义操作和任务，shell脚本/复制文件目录。
名称	            作用
file	            文件配置器，复制传输文件目录（需要远程连接）
local-exec	        本地执行shell命令
remote-exec 	    远程执行shell命令（需要远程连接）
connection	        定义连接远程主机的配置
                    resource
                    provisioner

### connection
``````
## 嵌套在resource
resource "xxx" "xxxx" {

  provisioner "xx" {
 
  }
  
  connection {
 
  
  }
}


## 嵌套在provisioner

provisioner "file" {
   
    connection {
      type     = "ssh"
      user     = "root"
      password = "${var.password}"
      host     = "${var.host}"
    }
} 
``````
● type ssh 、winrm   默认ssh
● user 远程的用户， Linux 中root、windows中的Administrator
● host 远程的主机IP  self.public_ip
● password 远程用户的密码
● port 端口， Linux 22， windows 5985
● timeout超时时间， 默认5m。 可以设置  3

### file 
复制源文件/opt/install.sh 到目标的/tmp/install.sh
``````
provisioner "file" {
    source      = "/opt/install.sh"
    destination = "/tmp/install.sh"
    
    connection {
      type     = "ssh"
      user     = "root"
      password = "${var.password}"
      host     = "${var.host}"
    }
} 
``````
● source  源文件
● content 源文件内容
● destination 目标文件

### local-exec
``````
provisioner "local-exec" {
    command = "touch versions.txt"
}
``````
● command [必填] 运行的shell命令
● work_dir 脚本运行的目录
● interpreter 执行命令的解释器参数列表，默认使用操作系统中的默认值。
● environment 访问terraform的变量，传递到command
● when 何时执行


### remote_exec
``````
provisioner "remote-exec" {
    inline = [
      "touch index.html",
      "echo helloworld  >> index.html"
    ]
    
    connection {
      type     = "ssh"
      user     = "root"
      password = "${var.password}"
      host     = "${var.host}"
    }
    
}
``````
