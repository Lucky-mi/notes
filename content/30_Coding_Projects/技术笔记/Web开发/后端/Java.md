java介于编译型与解释型语言之间，将代码编译成一种字节码，类似抽象cpu指令，针对不同平台编写虚拟机，加载字节码执行，“一次编写，到处运行”
JVM兼容性好
![[{D04F9CB0-9291-42A1-AADF-5829F740FD01}.png]]
- JDK：Java Development Kit
- JRE：Java Runtime Environment
JRE运行Java字节码的虚拟机
![[{8713EB93-7E23-4D00-9BBC-2D0416311FDB}.png]]
java字节码以.class结尾
![[{F20C585D-220C-4DAD-ABA6-67740F3EA62D}.png]]
可执行文件`javac`是编译器，而可执行文件`java`就是虚拟机
给虚拟机传递的参数是类名（没有后缀）

不写`public`，也能正确编译，但是这个类将无法从命令行执行。
```java
public class Hello{
	public static void main(String[] args)
	}
/**
 * 可以用来自动创建文档的注释
 * 
 * @auther liaoxuefeng
 */
```
Java入口程序规定的方法必须是静态方法，方法名必须为`main`，括号内的参数必须是String数组。
才发现……：浮点数`0.1`在计算机中就无法精确表示
Java的字符串除了是一个引用类型外，还有个重要特点，就是字符串不可变。
![[{A7632D6C-5DA6-44B3-A099-364D72185DF8}.png]]
```java
public class Main{
	int[] ns;
	ns=new int[] {68,79,20,3};
	System.out.println(ns.length);
	ns=new int[] {1,2,3};
	System.out.println(ns.length);
	}
```
![[{2F777A7F-DC6F-4329-90CD-FE0F3E265111}.png]]
println: printline
判断浮点数应当小于某个临界值，而不是直接相等判断
判断引用内容是否相等应用equals()
```java
Arrays.toString()
//可打印数组内容而不是位置
```
可变类型...
```java
    public void setNames(String... names) {
        this.names = names;
    }
    //String[]也行
```
调用构造方法必须用new
```java
class Student extends Person{}
```
子类引用父类的字段时可以用super.name
任何class的构造方法第一行语句必须是调用父类的构造方法，没调编译器会自动加一句super()
构造器链，如果父类没有无参构造方法，必须手动调用super(参数)
子类_不会继承_任何父类的构造方法。子类默认的构造方法是编译器自动生成的，不是继承的
```java
class A {
    // 编译器会自动生成一个无参构造方法：public A() { super(); }
}
class B extends A {
    // 编译器会自动生成一个无参构造方法：public B() { super(); }
}
public class Main {
    public static void main(String[] args) {
        B b = new B(); // 这是可行的，因为B有它自己的默认构造方法
    }
}
```
默认的 `equals()` 实现只是简单地检查两个对象的内存地址是否相同（即它们是否指向同一个对象）
**浅拷贝**:复制引用，不复制对象
继承是is关系，组合是has关系。
子类如果定义了一个与父类方法签名完全相同的方法，被称为覆写（Override）
Override和Overload不同的是，如果方法签名不同，就是Overload，Overload方法是一个新方法；如果方法签名相同，并且返回值也相同，就是`Override`。
多态的特性就是，运行期才能动态决定调用的子类方法
用`final`修饰的方法不能被`Override`,用`final`修饰的类不能被继承
如果一个`class`定义了方法，但没有具体执行代码，这个方法就是抽象方法，抽象方法用`abstract`修饰。
接口，最抽象：
```java
interface Person {
    void run();
    String getName();
}
```
接口定义的所有方法默认都是`public abstract`的
一个具体的`class`去实现一个`interface`时，需要使用`implements`关键字。
接口实现多态和解耦
### static静态
静态字段只有一个共享空间，实例对象没有静态字段，只是编译器根据实例转换的 类名.静态字段
静态方法常用于工具类
`interface`的字段只能是`public static final`类型
自动导入的是java.lang包，但类似java.lang.reflect这些包仍需要手动导入。
**基本类型变量存的是“值”，引用类型变量存的是“地址”**

### 核心类
#### 字符串
```java
// String
public class Main {
    public static void main(String[] args) {
        String s = "Hi %s, your score is %d!";
        System.out.println(s.formatted("Alice", 80));
        System.out.println(String.format("Hi %s, your score is %.2f!", "Bob", 59.5));
    }
}
```
string和char相互转换
```java
char[] cs = "Hello".toCharArray(); // String -> char[]
String s = new String(cs); // char[] -> String

```
自动装箱和自动拆箱只发生在编译阶段，目的是为了少写代码。

这种`class`被称为`JavaBean`：
```java
// 读方法:
public Type getXyz()
// 写方法:
public void setXyz(Type value)
```
枚举类enum
`enum`是一个`class`，每个枚举的值都是`class`实例
### 异常
抛出异常：
```java
void process2(String s) {
    if (s==null) {
        throw new NullPointerException();
    }
}
```
打印异常栈： e.printStackTrace();
NPE空指针异常
严禁使用catch隐藏“NullpointerException”错误
不能catch的异常：
不应该捕获Error及其子类，应该程序终止，记录日志，在代码层面解决


### 反射
程序在运行期可以拿到一个对象的所有信息
反射是为了解决在运行期，对某个实例一无所知的情况下，如何调用其方法。
通过`Class`实例获取`class`信息的方法称为反射
### 注解
编译器使用：
@override
@SuppressWarnings
处理.class使用
程序运行期最常用
### 泛型
泛型就是定义一种模板，例如`ArrayList<T>`，然后在代码中为用到的类创建对应的`ArrayList<类型>`
泛型类型`<T>`不能用于静态方法。
擦拭法：
</T>不能是基本类型 
无法取得带泛型的Class
无法判断带泛型的类型
不能实例化T类型

正确：
```java
public class Pair<T> {
    private T first;
    private T last;
    public Pair(Class<T> clazz) {
        first = clazz.newInstance();
        last = clazz.newInstance();
    }
}
```

### Java集合
java.util提供集合类：Collection根接口，
List,有序列表
Set,没有重复元素集合
Map键值查找映射表集合
接口和实现类相分离
访问集合用迭代器实现
##### List
接口方法：
末尾添加一元素：boolean add(E e)
在指定索引添加一个元素：boolean add(int index,E e)
删除指定元素： E remove(int index)
```java
import java.util.List
List<Integer> list=List.of(12,34)
Number[] array=list.toArray(new Number[3])
for(Number n:array)

```
## JVM
JVM内存模型
![[Pasted image 20250901104637.png]]
AQS
