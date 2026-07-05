# API接口说明文档

# 概述

本接口文档描述了智能泌乳Agent提供的标准API，用于与客户端（App）进行数据交互。  
文档版本：v1.3  
更新日期：2026-05-07  
协议：所有接口均使用 HTTP/HTTPS 协议

---

# 通用说明

## 请求规范

### 认证方式

除公开接口外，所有接口需要在请求头中携带访问令牌：

```http
Authorization: Bearer app-test
```
---

### 请求格式

*   所有POST/PUT请求必须设置正确的Content-Type：
    
    *   对于数据上传：
        
    
    ```http
    Content-Type: application/json
    ```
    *   对于文件上传：
        

```http
Content-Type: multipart/form-data
```

*   GET请求通过params传输查询参数（使用URL编码）：
    

```python
import requests


url = 'https://httpbin.org/query'
params = {
    'name': '张三',
    'age': 25,
    'city': '北京'
}

response = requests.get(url, params=params)

# 查看实际请求的 URL（包含编码后的参数）
print(response.url)
# 输出：https://httpbin.org/get?name=%E5%BC%A0%E4%B8%89&age=25&city=%E5%8C%97%E4%BA%AC

# 获取服务器返回的 JSON 数据（示例接口会回显参数）
print(response.json())
```
---

## 响应规范

### 同步响应

返回格式为：application/json

发起请求的stream参数为：false

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| status | number | 是 | 响应状态码，具体值详见2.2.3 状态码 |
| message | string | 是 | 执行结果的描述，一般用于描述出现异常的具体原因 |
| data | object | 是 | 详见章节3中的API接口描述 |

```json
{
  "status": 200,
  "message": "操作成功",
  "data": {
    // 响应数据
  }
}
```
---

### 状态码

| 错误码 | 说明 |
| --- | --- |
| 200 | 请求成功 |
| 400 | 请求参数错误 |
| 401 | 未授权，token无效或过期 |
| 403 | 无权限访问 |
| 404 | 资源不存在 |
| 409 | 资源冲突（如用户名已存在） |
| 422 | 请求参数校验失败 |
| 429 | 请求过于频繁 |
| 500 | 服务器内部错误 |

---

# 详细API接口说明

目前将分别从通用接口、对话交互、吸乳进程、主动奶量管理、设备使用指导五个方面的场景来对API接口进行说明。

## 通用接口

### 文件上传

*   **接口描述**
    

 用于上传文件，包括图片文件、文本文件(今天只支持图片)。

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/files/upload`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |

*   **请求参数 (file)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| file | object | 是 | （文件，文件内容，扩展名 png / jpeg / jpg / webp / gif） |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| id | string | 是 | 文件的唯一编码 |
| name | string | 是 | 文件的名称 |
| size | integer | 是 | 文件大小 |
| extension | string | 是 | 文件的后缀 |
| mime\_type | string | 是 | 文件的类型 |

### tts转换接口

*   **接口描述**
    

 用于将上传的文字合成语音文件并返回。

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/tts-stream`
        
    *   **方法**: `GET`
        
    *   **stream**：true
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
| text | string | 是 | 需要合成的文本 |

*   **响应参数**
    

以文件流的方式返回，返回的内容包含文件名、文件格式和语音文件内容。

---

## 吸乳进程

### 耐受度滴定阈值上报

*   **接口描述**
    

 上传耐受度滴定的阈值，后端收到请求后，先判读是否存在该用户的阈值；如果没有则新增，如果有则修改阈值。user\_id需要作为主键，保证唯一性。

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/pump/threshold/upload`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
| stimulate\_level\_l | integer | 是 | 左侧设备刺激模式的档位阈值（取值范围为1-15） |
| deep\_level\_l | integer | 是 | 左侧设备深度模式的档位阈值（取值范围为1-15） |
| stimulate\_level\_r | integer | 是 | 右侧设备刺激模式的档位阈值（取值范围为1-15） |
| deep\_level\_r | integer | 是 | 右侧设备深度模式的档位阈值（取值范围为1-15） |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |

### 耐受度滴定阈值查询

*   **接口描述**
    

 客户端发起查询耐受度滴定阈值的请求

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/pump/threshold/get`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| stimulate\_level\_l | integer | 是 | 左侧设备刺激模式的档位阈值（取值范围为1-15） |
| deep\_level\_l | integer | 是 | 左侧设备深度模式的档位阈值（取值范围为1-15） |
| stimulate\_level\_r | integer | 是 | 右侧设备刺激模式的档位阈值（取值范围为1-15） |
| deep\_level\_r | integer | 是 | 右侧设备深度模式的档位阈值（取值范围为1-15） |

### 上传设备的工作状态

*   **接口描述**
    

 上传设备的工作状态，包括是否工作、档位、模式等信息

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/pump/workstate`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    
    | 参数名 | 类型 | 必填 | 说明 |
    | --- | --- | --- | --- |
    | user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
    | device\_left | object | 是 | 左侧设备的工作状态 |
    | device\_right | object | 是 | 右侧设备的工作状态 |
    
    *   **device\_left 和 device\_right对象的数据结构**
        

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| state | integer | 是 | 设备的工作状态：<br>0 - 暂停中<br>1 - 正在运行<br>2 - 关机<br>3 - 离线<br>4 - 未配对 |
| scene | string | 否 | auto - 自动场景<br>manual - 手动场景 |
| mode | string | 否 | stimulate - 刺激模式<br>deep - 深度模式<br>mix - 混合模式 |
| level | integer | 否 | 设备运行时的档位 |
| process | integer | 否 | 吸乳进程的百分比 |
| timestamp | string | 否 | 设备状态切换时的时间（在设备开机的情况下必须传） |
| change\_type | string | 否 | 设备状态改变的原因：（在设备开机的情况下必须传）<br>app - 从app端调节<br>agent - 从agent端下发修改<br>device - 从设备端修改 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |

### 上传设备的吸乳情况

*   **接口描述**
    

 上传设备在工作时的吸乳情况，包括是否奶量、奶阵、吸乳进程等信息

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/pump/process`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    
    | 参数名 | 类型 | 必填 | 说明 |
    | --- | --- | --- | --- |
    | user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
    | process\_left | object | 是 | 左侧设备的吸乳进程 |
    | process\_right | object | 是 | 右侧设备的吸乳进程 |
    
    *   **process\_left 和 process\_right对象的数据结构**
        

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| process | integer | 是 | 吸乳进程的百分比 |
| cap\_data | number | 是 | 奶阵的电容数据（小数，保留两位） |
| time | string | 是 | 吸奶时间（UTC） |
| milk\_reel | integer | 是 | 设备吸乳通道的标记<br>bit0：通道是否有奶<br>bit1：是否有奶阵 |
| bandpower | number | 是 | 奶阵电容数据归一化处理后的bandpower值 |
| milk | number | 是 | 当前的奶量 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |

### 获取设备的吸乳进程

*   **接口描述**
    

 客户端向服务端传输奶阵、奶量和通道标记等数据，服务端根据用户的配置参数，计算出吸乳进程的百分比，并返回给客户端。

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/pump/process/data`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
| device\_left | object | 是 | 左侧设备的吸乳数据 |
| device\_right | object | 是 | 右侧设备的吸乳数据 |

*   **device\_left 和 device\_right对象的数据结构**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| step | string | 是 | start：第一次上报电容及泌乳数据时上报<br>running：在第一次上报之后，上报running<br>offline：设备蓝牙断联<br>pause：暂停，数据暂停上报<br>stop：在结束吸乳时上报stop |
| cap\_data | array\[number\] | 是 | 奶阵的电容数据（数值类型为小数，保留两位） |
| time | string | 是 | 吸奶时间（UTC -- 示例：“2026-04-16 17:49:49”） |
| milk\_reel | integer | 是 | 设备吸乳通道的标记<br>bit0：通道是否有奶<br>bit1：是否有奶阵 |
| bandpower | integer | 是 | 奶阵电容数据归一化处理后的bandpower值 |
| milk | integer | 是 | 当前的奶量 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| text | string | 是 | 吸乳进程计算失败的原因 |
| process\_l | integer | 是 | 左侧设备的吸乳进程 |
| process\_r | integer | 是 | 右侧设备的吸乳进程 |
| process\_all | integer | 是 | 左右综合的吸乳进程 |

## 妈妈宝宝数据

### 妈妈及宝宝信息查询

*   **接口描述**
    

 客户端发起查询妈妈和宝宝信息的请求

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/mom-baby/info/query`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| delivery\_date | string | 是 | 分娩时间，字符串格式为“20xx-xx-xx” |
| lactation\_advice | string | 是 | 产后的泌乳建议 |
| feeding\_advice | string | 是 | 宝宝的喂养建议 |

### 查询今日母乳产出和宝宝摄入情况

*   **接口描述**
    

 查询妈妈的今日母乳产出总量和宝宝摄入总量

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/mom-baby/today/query`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| pump\_milk\_volum | number | 是 | 吸乳总量，单位为毫升，包含补录、吸奶器上报的数据和亲喂估算 |
| feeding\_volum | number | 是 | 喂养总量，单位为毫升，包含补录、吸奶器上报的数据和亲喂估算 |
| feeding\_forecast\_volum | number | 是 | 喂养预估总量 |

### 新增宝宝生长发育记录

*   **接口描述**
    

 用于新增宝宝的生长发育记录

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/growth/add`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |
| height\_cm | integer | 是 | 宝宝的身高（单位：cm） |
| weight\_kg | number | 是 | 宝宝的体重（单位：kg） |
| head\_cm | integer | 是 | 宝宝的头围（单位：cm） |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| growth\_id | integer | 是 | 宝宝生长发育记录ID |

### 查询宝宝最近一次的生长发育记录

*   **接口描述**
    

 用于查询宝宝的最近一次生长发育数据

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/growth/query`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (Params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| growth\_id | integer | 是 | 宝宝生长发育记录ID |
| height\_mes\_time | string | 是 | 宝宝身高录入的时间（在新增或者修改时，后端自动生成的时间） |
| height\_cm | integer | 是 | 宝宝的身高（单位：cm） |
| weight\_mes\_time | string | 是 | 宝宝体重录入的时间（在新增或者修改时，后端自动生成的时间） |
| weight\_kg | number | 是 | 宝宝的体重（单位：kg） |
| head\_mes\_time | string | 是 | 宝宝头围录入的时间（在新增或者修改时，后端自动生成的时间） |
| head\_cm | integer | 是 | 宝宝的头围（单位：cm） |

### 修改宝宝的生长发育记录

*   **接口描述**
    

 用于修改宝宝的生长发育数据

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/growth/revise`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |
| growth\_id | integer | 是 | 宝宝生长发育记录ID |
| height\_cm | integer | 否 | 宝宝的身高（单位：cm） |
| weight\_kg | number | 否 | 宝宝的体重（单位：kg） |
| head\_cm | integer | 否 | 宝宝的头围（单位：cm） |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| growth\_id | integer | 是 | 宝宝生长发育记录ID |

### 妈妈最近一个月吸乳信息查询

*   **接口描述**
    

 客户端发起查询妈妈最近一个月吸乳信息情况的请求

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/pump/info/get`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| lactation\_info\_list | array\[object\] | 是 | 最近一个月每天的泌乳总量及参考数据 |

**lactation\_info\_list 字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| total\_milk | integer | 是 | 当天的泌乳总量，包括吸奶器上报和补录的数据 |
| totol\_milk\_estimate | integer | 是 | 当天的泌乳总量估计，包括吸奶器上报和补录的数据，以及亲喂时间转化成奶量 |
| reference\_upper | integer | 是 | 当天的泌乳参考上限值 |
| reference\_lower | integer | 是 | 当天的泌乳参考下限值 |
| delivery\_date | string | 是 | 当前的日期，几月几号 |

### 查询宝宝的生长发育历史记录

*   **接口描述**
    

 用于查询宝宝的生长发育历史数据

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/growth/history`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| growth\_data | array\[object\] | 是 | 生长发育数据列表 |

**growth\_data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| growth\_id | integer | 是 | 宝宝生长发育记录ID |
| height\_cm | integer | 是 | 宝宝的身高（单位：cm） |
| weight\_kg | number | 是 | 宝宝的体重（单位：kg） |
| head\_cm | integer | 是 | 宝宝的头围（单位：cm） |
| date | string | 是 | 记录的日期（YY-MM-DD） |

## 呵护计划

### 查询呵护计划详细任务内容

*   **接口描述**
    

 查询具体某一天的计划任务列表

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/plan/query-task`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
| timestamp | string | 是 | 需要查询的日期，格式为“20xx-xx-xx” |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| plan\_type | string | 是 | maintain: 维持奶量<br>chase: 逐步增量<br>wean: 温和离乳<br>fertility: 待产计划<br>None：未通过智能体制定计划 |
| task\_list | array\[object\] | 是 | 当天的任务列表 |

**task\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| task\_id | number | 是 | 任务的唯一Id |
| task\_time | string | 是 | 任务执行的时间 |
| task\_content | string | 是 | 任务描述 |
| task\_type | integer | 是 | 任务的类型：<br>0 - 吸奶<br>1 - 喂养<br>2  - 自定义 |
| task\_source | string | 是 | 任务的来源<br>Mai -- 系统生成<br>手动 -- 手动添加 |
| task\_done | string | 是 | 任务执行的状态<br>true - 任务已执行<br>false - 任务未执行<br>jump - 跳过任务 |

### 增加呵护计划的临时任务

*   **接口描述**
    

 用于增加呵护计划中的临时任务

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/plan/add-task`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |
| timestamp | string | 是 | 需要添加任务的日期，格式为“20xx-xx-xx” |
| task\_list | array\[object\] | 是 | 需要增加的任务列表 |

**task\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| task\_time | string | 是 | 任务执行的时间 |
| task\_content | string | 是 | 任务描述 |
| task\_type | integer | 是 | 0 - 吸奶<br>1 - 喂养<br>2 - 自定义 |
| task\_source | string | 是 | 手动 -- 手动添加 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| task\_list | array\[object\] | 是 | 增加新任务之后更新的任务列表 |

**task\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| task\_id | integer | 是 | 任务的唯一Id |
| task\_time | string | 是 | 任务执行的时间 |
| task\_content | string | 是 | 任务描述 |
| task\_type | integer | 是 | 任务的类型：<br>0 - 吸奶<br>1 - 亲喂<br>2  - 自定义 |
| task\_source | string | 是 | 任务的来源<br>Mai -- 系统生成<br>手动 -- 手动添加 |
| task\_done | string | 是 | 任务执行的状态<br>true - 任务已执行<br>false - 任务未执行<br>jump - 跳过任务 |

### 删除呵护计划的任务

*   **接口描述**
    

 用于删除呵护计划的任务

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/plan/delete-task`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |
| timestamp | string | 是 | 需要删除任务的日期，格式为“20xx-xx-xx” |
| task\_id | integer | 是 | 任务的id号 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| task\_list | array\[object\] | 是 | 删除任务之后更新的任务列表 |

**task\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| task\_id | integer | 是 | 任务的唯一Id |
| task\_time | string | 是 | 任务执行的时间 |
| task\_content | string | 是 | 任务描述 |
| task\_type | integer | 是 | 任务的类型：<br>0 - 吸奶<br>1 - 喂养<br>2  - 自定义 |
| task\_source | string | 是 | 任务的来源<br>Mai -- 系统生成<br>手动 -- 手动添加 |
| task\_done | string | 是 | 任务执行的状态<br>true - 任务已执行<br>false - 任务未执行<br>jump - 跳过任务 |

### 修改呵护计划的临时任务

*   **接口描述**
    

 用于修改呵护计划中的临时任务

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/plan/revise-task`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |
| task\_id | integer | 是 | 任务的唯一Id |
| timestamp | string | 是 | 需要修改任务的日期，格式为“20xx-xx-xx” |
| task\_time | string | 是 | 任务执行的时间 |
| task\_content | string | 是 | 任务描述 |
| task\_done | string | 是 | 任务执行的状态<br>true - 任务已执行<br>false - 任务未执行<br>jump - 跳过任务 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| task\_list | array\[object\] | 是 | 修改任务之后更新的任务列表 |

**task\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| task\_id | integer | 是 | 任务的唯一Id |
| task\_time | string | 是 | 任务执行的时间 |
| task\_content | string | 是 | 任务描述 |
| task\_type | integer | 是 | 任务的类型：<br>0 - 吸奶<br>1 - 亲喂<br>2  - 自定义 |
| task\_source | string | 是 | 任务的来源<br>Mai -- 系统生成<br>手动 -- 手动添加 |
| task\_done | string | 是 | 任务执行的状态<br>true - 任务已执行<br>false - 任务未执行<br>jump - 跳过任务 |

### 新增宝宝今日喂养记录

*   **接口描述**
    

 用于新增宝宝的喂养记录

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/feeding/add`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |
| feed\_type | integer | 是 | 宝宝的喂养方式<br>0：亲喂<br>1：母乳瓶喂<br>2：配方奶瓶喂 |
| feed\_action | integer | 是 | 喂养记录触发的方式<br>0：手动<br>1：计划 |
| feed\_time | string | 是 | 喂养时间（**格式限制HH:MM, 日期自动选择今天**） |
| feed\_milk\_volum | integer | 是 | 喂养量<br>如果是瓶喂，则单位为ml；如果是亲喂，单位为min |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| feeding\_id | integer | 是 | 喂养记录ID |

### 删除宝宝今日喂养记录

*   **接口描述**
    

 用于删除宝宝的喂养记录

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/feeding/delete`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |
| feeding\_id | integer | 是 | 喂养记录ID |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |

### 查询宝宝今日喂养记录

*   **接口描述**
    

 用于查询宝宝的今日喂养记录

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/feeding/query`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。根据请求参数，返回满足搜索条件的当日的所有数据

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| feed\_list | array\[object\] | 是 | 喂养记录的列表 |

**feed\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| feeding\_id | integer | 是 | 喂养记录的唯一id |
| feed\_type | integer | 是 | 宝宝的喂养方式<br>0：亲喂<br>1：母乳瓶喂<br>2：配方奶瓶喂 |
| feed\_action | integer | 是 | 喂养记录触发的方式<br>0：手动<br>1：计划 |
| feed\_time | string | 是 | 喂养时间 |
| feed\_milk\_volum | integer | 否 | 瓶喂时的喂养量，则单位为ml |
| feed\_duration | integer | 否 | 亲喂时的喂养时长，单位为分钟 |

### 上传妈妈的泌乳情况

*   **接口描述**
    

 上传妈妈的泌乳情况，包括吸奶器吸奶、补录和亲喂的场景

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/pump-milk/upload`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
| pump\_type | integer | 是 | 吸奶方式：<br>0 - 吸奶器上报奶量<br>1 - 补录 |
| pump\_source | integer | 是 | 吸乳来源方式：<br>0 - 设备<br>1 - 手动<br>2 - 计划 |
| pump\_time | string | 是 | 吸乳的时间（**只有时间HH:MM， 日期自动取今天**） |
| pump\_milk\_volum | number | 否 | 吸乳总量，单位为毫升，主要是补录和吸奶器上报的数据 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| pump\_id | number | 是 | 增加吸奶时的唯一Id |

### 删除妈妈的泌乳情况

*   **接口描述**
    

 删除妈妈的泌乳情况，包括补录和亲喂的场景

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/pump-milk/delete`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
| pump\_id | number | 是 | 增加吸奶记录时返回的唯一Id |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |

### 查询当天妈妈的泌乳情况

*   **接口描述**
    

 查询妈妈的吸乳情况，包括吸奶器上报、补录和亲喂的场景

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/pump-milk/query`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| pump\_milk\_list | array\[object\] | 是 | 吸奶记录的列表 |

**pump\_milk\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| pump\_id | number | 是 | 增加吸奶记录时返回的唯一Id |
| pump\_type | integer | 是 | 吸奶方式：<br>0 - 吸奶器上报奶量<br>1 - 补录<br>（忽略由feeding\_log同步的pump\_type=2的数据） |
| pump\_source | integer | 是 | 吸乳来源方式：<br>0 - 设备<br>1 - 手动<br>2 - 计划 |
| pump\_time | string | 是 | 吸乳的时间 |
| pump\_milk\_volum | number | 是 | 吸乳总量，单位为毫升，主要是补录和吸奶器上报的数据 |

## 设备使用指导

### 上传设备的连接情况

*   **接口描述**
    

 上传设备当前的连接情况

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/device/info`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    
    | 参数名 | 类型 | 必填 | 说明 |
    | --- | --- | --- | --- |
    | user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
    | device\_left | object | 是 | 左侧设备的连接情况 |
    | device\_right | object | 是 | 右侧设备的连接情况 |
    
    *   **process\_left 和 process\_right对象的数据结构**
        

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| model | string | 是 | 设备型号 |
| state | string | 是 | 左侧设备的状态<br>online：在线<br>offline：离线<br>unbind：未绑定 |
| battery | integer | 是 | 左侧电池电量百分比 |
| sn | string | 是 | 设备SN序列号 |
| rssi | integer | 是 | 设备的信号强度 |
| version | string | 是 | 设备的版本号 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 设备状态上报结果<br>0：上报成功<br>\-1：上报失败 |

## 系统级后台任务

### 查询推送消息

*   **接口描述**
    

 从服务端查询需要推送的消息内容

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/notify/query`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
| timestamp | string | 是 | 当前app中的时间，用于后端校验是否有需要提醒的消息列表 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 设备状态上报结果<br>0：上报成功<br>\-1：上报失败 |
| notify\_list | array\[object\] | 是 | 需要提醒的消息列表 |

notify\_list字段说明：

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| event | string | 是 | event字段内容：<br>pump -- 吸奶/亲喂提醒<br>warning -- 风险预警<br>grown -- 宝宝生长发育指标更新提醒<br>summary -- 每日奶量小结 |
| time | string | 是 | 时间执行的时间，格式为“HH:MM” |
| message | string | 是 | 消息提醒的内容 |

### 执行泌乳和喂养的分析

*   **接口描述**
    

 APP端定时向服务端发起请求，让服务端执行泌乳和喂养的数据分析，生成泌乳建议和喂养建议。

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/status/create`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 设备状态上报结果<br>0：上报成功<br>\-1：上报失败 |

### 执行每日奶量及阶段泌乳和喂养分析

*   **接口描述**
    

 APP端向服务器发起请求，让服务器执行每日奶量或者阶段性泌乳喂养分析。

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/analysis/create`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
| type | string | 是 | mom-baby：妈妈泌乳情况和宝宝喂养情况的分析<br>daily\_summary：每日小结 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 设备状态上报结果<br>0：上报成功<br>\-1：上报失败 |
| result | Boolean | 否 | 在泌乳和喂养分析时返回该字段，每日小结不需要<br>true：代表分析结果正常（两者都正常）<br>false：代表泌乳或者喂养存在风险（任一不正常） |
| message | string | 是 | 泌乳喂养建议或者每日小结的分析结果 |
