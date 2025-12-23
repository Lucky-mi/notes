## css基础：
伪类：用于将鼠标移到元素上是设置元素样式等，访问未访问不同的样式
hover：mouse over link必须定义在link和visited后
p:hover……
伪元素：设置元素特定部分的样式
z-index 定位元素
#### 响应式网页设计RWD
为了手机、平板、电脑不同设备适应网页
视口：<meta name="viewport" content="width=device-width, initial-scale=1.0">
## JavaScript基础
DOM是访问文档的标准
jQuery是javascript的库
查找HTML元素，：通过id，通过标签名称，通过css选择器，通过HTML对象集合
window.alert() 用警告框显示数据！！就是那个警告框，但是显示的是数据，文字用双引号
![[{BFDBEE1F-670A-41AD-8D0D-46A048A3ABDD}.png]]
用let、var、const声明变量，值可以是数字和字符串，var是旧版浏览器编写代码
const值不改变，var可以重新声明，仍为原值
//如果将数字放在引号中，其余数字将被视为字符串并连接起来。
```js
let x = 2 + 3 + "5";
x=55
```
JavaScript 将美元符号视为字母，因此包含 $ 的标识符是有效的变量名
const声明不能重新分配常量数组，可以改变常量数组的元素；不能重分配常量对象，可以改变常量对象的属性
```js
// You can create a const object:  
const car = {type:"Fiat", model:"500", color:"white"};  
  
// You can change a property:  
car.color = "red";
```
块作用域：let、const
//当添加一个数字和一个字符串时，JavaScript 会将数字视为字符串。不同的顺序会产生不同的结果
BigInt 可用于存储太大而无法用普通 JavaScript 数字表示的整数值
两种对象表示方式：
object.property/object["property"]
object.values()根据属性值创建一个数组
object.entries() 在循环中使用对象
比如：
```js
const fruits = {Bananas:300, Oranges:200, Apples:500};  
  
let text = "";  
for (let [fruit, value] of Object.entries(fruits)) {  
  text += fruit + ": " + value + "<br>";  
}
```
添加新属性：Person.prototype.nationality = "English";
尽量避免这样创建字符串：
```js
let x=new String("Ma")
```
`Number.EPSILON`是大于 1 的最小浮点数与 1 之间的差。
## Vue入门
SFC单文件组件，封装在一个文件中
还是要会js、css啥的
用vue-cli脚手架创建，用vite创建
**vite**按需编译
**webpack** 构建较慢，都处理
##### vite创建
```cmd
npm create vue@latest
```
src工作文件夹
Options API的弊端：分散，修改需求难
Composition API更优雅组织代码 组合式api
setup（）{}
响应式的数据改了以后可以更新
- setup与传统配置项（data、method）可以同时写吗？
可以同时存在，setup里的数据data里可以读到，原写法可以读取新写法的，但是新的不能读旧的

语法糖：不用return
```js
<script setup>
let a=777;
</script>
```