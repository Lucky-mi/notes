## JavaScript
异步编程：该任务运行时仍然能响应其他事件，
回调是实现异步函数的主要方式 
### 异步函数表达式
async function声明一个绑定到给定名称的新异步函数，内部允许使用await关键字，可编写基于promise的异步函数
### 立即调用函数表达式（IIFE）：
用括号括起来的函数表达式
用例：创建新的作用域避免污染全局命名空间，创建新异步上下文在非异步上下文中使用await，使用复杂的逻辑计算值
比较常见是匿名函数
例：
```js
//标准
(function(){

})();

//异步
(async()=>{

})()
```
**1.创建只使用一次的函数，立即执行它**

**2.创建闭包，保持状态，隔离作用域**
#### 闭包
https://www.ruanyifeng.com/blog/2009/08/learning_javascript_closures.html
js函数内部可以直接读取全局变量 //虽然其他的也可以
函数内部声明变量要用var声明，否则声明的是全局变量！
外部无法得到局部变量
*链式作用域（chain scope）*：所有父对象的变量对子对象都是可见的
闭包：定义在函数内部的函数，可以读取其他函数内部变量的函数
**用途：** 读取函数内部变量、让变量值始终保持在内存中
例：f2返回出去，带着n的引用离开了f1作用域
```js
function f1(){
	var n=99;
	function f2(){
		alert(n);
	}
	return f2;
}
```
- js中将变量赋值为函数则可以像函数一样使用
但是用闭包会使内存消耗变大
以下是会输出全局变量，除非加上注释部分，局部声明
```js
　　var name = "The Window";

　　var object = {  
　　　　name : "My Object",

　　　　getNameFunc : function(){ 
　　　　//var name="The Object" 
　　　　　　return function(){  
　　　　　　　　return this.name;  
　　　　　　};

　　　　}

　　};

　　alert(object.getNameFunc()());
```
##### 例子
这个由于写文件是异步操作，在循环后调用回调函数，所以结果是3个：File 3 is written.
```js
var fs = require('fs');  
  
var fileContents = ["text1", "text2", "text3"];  
for (var i = 0; i < fileContents.length; i++) {  
  fs.writeFile("file"+i+".txt", fileContents[i], function(err){  
    if (err) {  
      console.log(err)  
    }  
    console.log("File " + i + " is written.")  
  })  
}
```
使用IIFE可以解决：(顺序可能不是对的)
变量捕获
```js
var fs = require('fs');  
  
var fileContents = ["text1", "text2", "text3"];  
for (var i = 0; i < fileContents.length; i++) {  
  (function(index){  
    var fileIndex = index;  
    fs.writeFile("file"+fileIndex+".txt", fileContents[fileIndex], function(err){  
      if (err) {  
        console.log(err)  
      }  
      console.log("File " + fileIndex + " is written.")  
    })  
  })(i)  
}
```
**3.作为独立模块存在，防止命名冲突，命名空间注入(模块解耦)**
