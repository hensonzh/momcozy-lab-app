# API接口说明文档V1.1

# 概述

本接口文档描述了智能泌乳Agent提供的标准API，用于与客户端（App）进行数据交互。  
文档版本：v1.2  
更新日期：2026-03-30  
协议：所有接口均使用 HTTP/HTTPS 协议

---

# 通用说明

## 请求规范

### 认证方式

除公开接口外，所有接口需要在请求头中携带访问令牌：

```http
Authorization: Bearer APP_API_TEST
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

### 流式（SSE流）响应

返回格式为：多行格式为`data: <JSON>\n\n`的text/plain数据。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| conversion\_id | string | 是 | 对话ID |
| event | string | 否 | 事件的类型，目前可分为tool\_calls，rich\_text，<br>message，<br>action |
| answer | string | 否 | 对话回答的详细内容 |
| tool\_calls | object | 否 | 工具回调的详细内容，正在展示给用户的信息 |
| rich\_text | object | 否 | 复文本的详细内容，<br>需要渲染的前端界面 |
| action\_content | object | 否 | APP下一步要执行的动作 |
| Emoji | string | 是 | happy - 默认状态/日常陪伴/喂养充足<br>encourage - 日结/趋势向好/任务完成等正向激励<br>calm - 知识科普/目标设置/方案讲解<br>thinking - 数据分析/趋势解读/方案推算<br>alert - 喂养量偏离P15-P85范围时关切 |

action\_content

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| val | string | 否 | “add level” -- 加档<br>“dec level” -- 减档<br>“set level” -- 设置绝对档位<br>暂停 -- 设备暂停<br>恢复-- 设备恢复<br>刺激模式 --切换到刺激模式<br>吸乳模式 -- 切换到吸乳模式<br>模式切换 --当前为刺激，就切换为吸乳，当前为吸乳就切换为刺激模式 |
| level | integer | 否 | 当val=档位调节时，level是档位参数 |
| target\_scope | string | 否 | both / left / right |
| left\_stimulate\_level | integer | 否 | 左侧刺激模式滴定值 |
| left\_deep\_level | integer | 否 | 左侧深吸模式滴定值 |
| right\_stimulate\_level | integer | 否 | 右侧刺激模式滴定值 |
| right\_deep\_level | integer | 否 | 右侧深吸模式滴定值 |

共同决定是双侧调整还是某侧调整

**注：tool\_calls和rich\_text字段的详细参数说明待补充。见**[《rich\_text接口》](https://alidocs.dingtalk.com/api/doc/transit?dentryUuid=93NwLYZXWybmGG3PuQ6zjvv0VkyEqBQm&queryString=utm_medium%3Ddingdoc_doc_plugin_card%26utm_source%3Ddingdoc_doc)

```json
data:{"conversion_id": "xxxxxxxxxxxxxxxx","event":"tool_calls", "answer": "{answer具体内容}(工具调用户提示)", "tool_calls":"{tool_calls具体内容}（工具名、工具参数）"}
data:{"conversion_id": "xxxxxxxxxxxxxxxx","event":"rich_text", "rich_text":"{rich_text具体内容}(需与前端共识，由前端渲染)"}
data:{"conversion_id": "xxxxxxxxxxxxxxxx","event":"message", "answer":"{answer具体内容..}"}
data:done
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

### asr转换接口

*   **接口描述**
    

 用于将上传的语音文件转化为文本。

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/asr`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| text | string | 是 | 通过`/v1/asr/upload`接口返回的文本内容 |

*   **响应参数**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| text | string | 是 | 语音的文本内容 |

### asr文件上传接口

*   **接口描述**
    

 用于上传语音文件接口，后端将语音文件转化为文本输出

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/asr/upload`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (file)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| file | object | 是 | （文件，文件内容，扩展名wav/mp3/pcm） |

*   **响应参数**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| raw\_text | string | 是 | 原始文本内容 |
| text | string | 是 | 语音的文本内容 |

## 对话交互

### 对话上传

*   **接口描述**
    

 客户端上传对话数据

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/chat-messages`
        
    *   **方法**: `POST`
        
    *   **stream**：true
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| agent | string | 是 | agent的名称，指定调用的agent |
| input | object | 否 | 需要上传给Agent的参数 |
| query | string | 是 | 需要上传的对话内容 |
| response\_mode | string | 是 | streaming/blocking |
| conversation\_id | string | 是 | 对话的Id，在对话建立接口返回的conversation\_id |
| user | string | 是 | 用户的唯一id |
| files | array\[object\] | 是 | 上传的文件列表 |
| memory\_immit | object | 否 | 历史记忆 -- 调试使用 |

files**字段描述**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| type | string | 是 | 文件类型，目前固定为“image” |
| transfer\_method | string | 是 | 文件的传输方式，目前固定为“local\_file” |
| upload\_file\_id | string | 是 | 文件的id号，是通过文件上传接口返回的唯一编码 |

*   **响应参数**
    

详见“2.2.2 流式（SSE流）响应”章节中的描述。

### 对话打断接口

*   **接口描述**
    

 打断当前的对话

*   **请求信息**
    
    *   **URL**: `/v1/workflows/tasks/{conversation_id}/stop`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |

*   **响应参数**
    

详见“2.2.1 同步响应”章节中的描述。执行结果通过status字段进行判断。

### 获取历史对话接口

*   **接口描述**
    

 获取指定数量的历史对话

*   **请求信息**
    
    *   **URL**: `/v1/chat-message/history`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
| conversation\_id | string | 是 | 对话的唯一id |
| count | integer | 是 | 获取历史对话的数量 |

*   **响应参数**
    

详见“2.2.1 同步响应”章节中的描述。

**data字段描述**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| 待补充 |  |  |  |

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
| need\_reply | boolean | 是 | true：智能体回复的消息需要展示<br>false：智能体回复的消息不需要展示 |
| output | string | 是 | 智能体回复的消息 |
| reply\_code |  |  | 用来标识回复触发原因 |
| reply\_side |  |  | 用来标识回复触发侧 |
| direct\_rich\_text |  |  | 按钮富文本 |

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
| need\_reply | boolean | 是 | true：智能体回复的消息需要展示<br>false：智能体回复的消息不需要展示 |
| output | string | 是 | 智能体回复的消息 |
| reply\_code |  |  | 用来标识回复触发原因 |
| reply\_side |  |  | 用来标识回复触发侧 |
| direct\_rich\_text |  |  | 按钮富文本 |

### 乳房健康上报

*   **接口描述**
    

 上传妈妈的乳房健康问题。

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/pump/health/upload`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
| health\_l | integer | 是 | 左侧乳房的健康状况<br>0：未见异常<br>1：损伤风险<br>2：需要关注 |
| health\_r | integer | 是 | 右侧乳房的健康状况<br>0：未见异常<br>1：损伤风险<br>2：需要关注 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |

### 乳房健康查询

*   **接口描述**
    

 客户端发起查询乳房健康的请求

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/pump/health/get`
        
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
| health\_l | integer | 是 | 左侧乳房的健康状况<br>0：未见异常<br>1：损伤风险<br>2：需要关注 |
| health\_r | integer | 是 | 右侧乳房的健康状况<br>0：未见异常<br>1：损伤风险<br>2：需要关注 |

### 妈妈吸乳信息查询

*   **接口描述**
    

 客户端发起查询妈妈吸乳信息情况的请求

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
| delivery\_week | integer | 是 | 产后时间：产后的第几周 |
| delivery\_tage | string | 是 | 产后的泌乳阶段，分为泌乳启动期、泌乳建立期、泌乳维持期 |
| lactation\_advice | string | 是 | 产后的泌乳建议 |
| target\_progress | integer | 是 | 当前的目标进度 |
| lactation\_info\_list | array\[object\] | 是 | 最近一个月每天的泌乳总量及参考数据 |

**lactation\_info\_list 字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| total\_milk | integer | 是 | 当天的泌乳总量，包括吸奶器上报和补录的数据 |
| totol\_milk\_estimate | integer | 是 | 当天的泌乳总量估计，包括吸奶器上报和补录的数据，以及亲喂时间转化成奶量 |
| reference\_upper | integer | 是 | 当天的泌乳参考上限值 |
| reference\_lower | integer | 是 | 当天的泌乳参考下限值 |
| delivery\_date | string | 是 | 当前的日期，几月几号 |

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

### 乳势能释放目标查询

*   **接口描述**
    

 客户端发起查询乳势能释放目标的请求

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/pump/energy/get`
        
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
| upper\_value | integer | 是 | 奶阵势能的目标上限 （95%） |
| lower\_value | integer | 是 | 奶阵势能的目标下限 （85%） |

## 主动奶量管理

### 录入宝宝信息

*   **接口描述**
    

 用于录入宝宝信息，包括出生时间、性别等信息

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/baby-info/create`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
| birth\_date | string | 是 | 宝宝出生日期 |
| sex | string | 是 | 宝宝的性别 |
| name | string | 否 | 宝宝的姓名 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| infant\_id | integer | 是 | 宝宝的唯一ID |

### 查询宝宝信息

*   **接口描述**
    

 用于查询宝宝信息，包括出生时间、性别、喂养情况及建议等信息

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/baby-info/query`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
| infant\_id | integer | 否 | 宝宝的唯一ID，若该字段未指定具体的宝宝，则返回所有关联到user\_id的宝宝信息，以列表的形式返回所有的宝宝信息 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| baby\_info\_list | array\[object\] | 否 | 由一个或者宝宝的信息列表 |

**baby\_info\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| infant\_id | integer | 否 | 宝宝的唯一ID |
| birth\_date | string | 是 | 宝宝出生日期 |
| sex | string | 是 | 宝宝的性别 |
| growth\_status | string | 是 | 宝宝的生长发育情况和喂养建议<br>（使用\n 分割） |
| name | string | 否 | 宝宝的姓名 |

### 新增宝宝喂养记录

*   **接口描述**
    

 用于新增宝宝的喂养记录

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/feeding/add`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| infant\_id | integer | 是 | 宝宝的唯一ID |
| feed\_type | integer | 是 | 宝宝的喂养方式<br>0：亲喂<br>1：母乳瓶喂<br>2：配方奶瓶喂 |
| feed\_time | string | 是 | 喂养时间（**格式限制HH:MM, 日期自动选择今天**） |
| feed\_milk\_volum | integer | 是 | 喂养量<br>如果是瓶喂，则单位为ml；如果是亲喂，单位为min |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| feeding\_id | integer | 是 | 喂养记录ID |

### 删除宝宝喂养记录

*   **接口描述**
    

 用于删除宝宝的喂养记录

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/feeding/delete`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| infant\_id | integer | 是 | 宝宝的唯一ID |
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
| infant\_id | integer | 是 | 宝宝的唯一ID |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。根据请求参数，返回满足搜索条件的当日的所有数据

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| total\_feed | integer | 是 | 喂养总量，当日的喂养总量 |
| feed\_list | array\[object\] | 是 | 喂养记录的列表 |

**feed\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| infant\_id | integer | 是 | 宝宝的唯一ID |
| feeding\_id | integer | 是 | 喂养记录的唯一id |
| feed\_type | integer | 是 | 宝宝的喂养方式<br>0：亲喂<br>1：母乳瓶喂<br>2：配方奶瓶喂 |
| feed\_time | string | 是 | 喂养时间 |
| feed\_milk\_volum | integer | 是 | 瓶喂时的喂养量，则单位为ml |
| feed\_duration | integer | 是 | 亲喂时的喂养时长，单位为分钟 |

### 查询宝宝需求估算

*   **接口描述**
    

 用于查询宝宝喂养时的需求估算值

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/feeding/assess`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |
| infant\_id | integer | 是 | 宝宝的唯一ID |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。根据请求参数，返回满足搜索条件的当日的所有数据

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| p25\_value | integer | 是 | p25的喂养量 |
| p50\_value | integer | 是 | p50的喂养量 |
| p75\_value | integer | 是 | p75的喂养量 |

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
| infant\_id | integer | 是 | 宝宝的唯一ID |
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
| infant\_id | integer | 是 | 宝宝的唯一ID |

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
| infant\_id | integer | 是 | 宝宝的唯一ID |
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
| infant\_id | integer | 是 | 宝宝的唯一ID |

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

### 查询妈妈的呵护计划

*   **接口描述**
    

 用于查询妈妈的呵护计划

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/plan/query`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| plan\_type | string | 是 | maintain: 维持奶量<br>chase: 逐步增量<br>wean: 温和离乳<br>fertility: 待产计划<br>work: 返工计划 |
| plan\_summary | string | 是 | 计划的概括 |
| plan\_list | array\[object\] | 是 | 计划的所有信息（可有多个计划，但注意互斥，最多两个：待产和其他互斥；维持，追减奶，互斥） |

**plan\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| plan\_name | string | 是 | 计划的名称：<br>维持奶量（）<br>安心追奶<br>稳步减奶<br>待产计划<br>返工计划 |
| milestones\_summary | string | 是 | 当前milestone的进展概括 |
| milestones\_list | array\[object\] | 是 | 具体计划的执行时刻列表 |

**milestones\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| title | string | 是 | 具体计划的标题，一个milestone分为多个阶段，每个阶段有一个标题 |
| date | string | 是 | 具体计划开始执行的日期 |
| duration\_weeks | integer | 是 | 这个阶段持续的周数 |
| content | string | 是 | 具体计划的内容 |

### 查询妈妈的泌乳周期

*   **接口描述**
    

 用于查询妈妈的泌乳周期

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/plan/milk_period`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| milk\_period | object | 是 | 泌乳周期的时间段信息 |

**milk\_period字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| colostrum\_period | string | 是 | 初乳期开始的时间（YYYY-MM-DD） |
| establishment\_period | string | 是 | 建立期开始的时间（YYYY-MM-DD） |
| stable\_delivery\_period | string | 是 | 稳产期开始的时间（YYYY-MM-DD） |
| weaning\_period | string | 是 | 离乳期开始的时间（YYYY-MM-DD） |

### 查询妈妈当天的泵奶计划

*   **接口描述**
    

 用于查询妈妈当天的泵内计划 （包含类型：追奶，减奶，维奶， 返工）

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/plan-pump/today`
        
    *   **方法**: `GET`
        
    *   **stream**：false
        
*   **请求参数 (params)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| plan\_data | object | 是 | 当天计划的所有信息 |

**plan\_data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| plan\_id | integer | 是 | 计划的Id |
| plan\_name | integer | 否 | 计划的标题 |
| plan\_list | array\[object\] | 是 | 计划的执行列表 |

**plan\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| task\_id | integer | 是 | 任务的id号 |
| time | string | 是 | 计划执行的时间 |
| content | string | 是 | 计划的内容 |
| finish | boolean | 是 | 是否完成 |
| label | string | 否 | 计划的标签 |
| entry\_type | string | 是 | 任务的类型，字段：<br>plan -- 计划任务<br>avoid -- 避开时段 |

### 增加泵奶计划的避开时段

*   **接口描述**
    

 用于增加妈妈泵奶计划的避开时段

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/plan-pump/add-period`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |
| plan\_id | integer | 否 | 用户的计划id,若不传入该参数，则默认修则修改当天的参数 |
| content | string | 否 | 避开时段的内容 |
| start\_time | string | 是 | 需要避开时段的开始时间 |
| end\_time | string | 是 | 需要避开时段的结束时间 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| plan\_data | object | 是 | 当天计划的所有信息 |

**plan\_data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| plan\_id | integer | 是 | 计划的Id |
| plan\_name | integer | 否 | 计划的标题 |
| plan\_list | array\[object\] | 是 | 计划的执行列表 |

**plan\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| task\_id | integer | 是 | 任务的id号 |
| time | string | 是 | 计划执行的时间 |
| content | string | 是 | 计划的内容 |
| finish | boolean | 是 | 是否完成 |
| label | string | 否 | 计划的标签 |
| entry\_type | string | 是 | 任务的类型，字段：<br>plan -- 计划任务<br>avoid -- 避开时段 |

### 删除泵奶计划的避开时段

*   **接口描述**
    

 用于删除妈妈泵奶计划的避开时段

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/plan-pump/delete-period`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的唯一ID |
| plan\_id | integer | 否 | 用户的计划id,若不传入该参数，则默认修改当前的参数 |
| task\_id | integer | 是 | 任务的id号 |
| start\_time | string | 否 | 需要避开时段的开始时间 |
| end\_time | string | 否 | 需要避开时段的结束时间 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| plan\_data | object | 是 | 当天计划的所有信息 |

**plan\_data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| plan\_id | integer | 是 | 计划的Id |
| plan\_name | integer | 否 | 计划的标题 |
| plan\_list | array\[object\] | 是 | 计划的执行列表 |

**plan\_list字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| task\_id | integer | 是 | 任务的id号 |
| time | string | 是 | 计划执行的时间 |
| content | string | 是 | 计划的内容 |
| finish | boolean | 是 | 是否完成 |
| label | string | 否 | 计划的标签 |
| entry\_type | string | 是 | 任务的类型，字段：<br>plan -- 计划任务<br>avoid -- 避开时段 |

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
| pump\_type | integer | 是 | 吸奶方式：<br>0 - 吸奶器上报奶量<br>1 - 补录<br>2  - 亲喂 |
| pump\_time | string | 是 | 吸乳的时间（**只有时间HH:MM， 日期自动取今天**） |
| pump\_milk\_volum | number | 否 | 吸乳总量，单位为毫升，主要是补录和吸奶器上报的数据 |
| pump\_milk\_duration | integer | 否 | 吸乳的时长，用于记录亲喂或者其他方式吸乳的时长 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |
| pump\_id | number | 是 | 增加背奶时的唯一Id |

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
| pump\_type | string | 是 | 吸奶方式：<br>0 - 吸奶器上报奶量<br>1 - 补录<br>2  - 亲喂 |
| pump\_time | string | 是 | 吸乳的时间 |
| pump\_milk\_volum | number | 是 | 吸乳总量，单位为毫升，主要是补录和吸奶器上报的数据 |
| pump\_milk\_duration | integer | 否 | 吸乳的时长，用于记录亲喂或者其他方式吸乳的时长 |

### 设置当天计划的任务状态

*   **接口描述**
    

 设置当天计划的任务状态，用于用户在修改任务状态时同步到服务端

*   **请求信息**
    
    *   **URL**: `{base_url}/v1/plan-pump/update`
        
    *   **方法**: `POST`
        
    *   **stream**：false
        
*   **请求参数 (Body)**
    

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| user\_id | string | 是 | 用户的id，用于区分不同的用户，方便查询用户的具体信息 |
| plan\_id | number | 是 | 计划的Id |
| task\_id | number | 是 | 任务的唯一Id |
| finish | boolean | 是 | 任务的状态 |

*   **响应参数**
    

返回格式详见“2.2.1 同步响应”章节中的描述。

**data字段说明：**

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| error | integer | 是 | 请求执行结果<br>0：成功<br>\-1：失败 |

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

## 系统级后台推送提醒

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