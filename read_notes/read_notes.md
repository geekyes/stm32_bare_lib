# 阅读笔记总结

## 外设配置
- 在 `include/` 文件夹中，有如下文件：
```bash
$ tree ./include 
.\include\
├── adc.h
├── cmsis_predefs.h
├── core_stm32.h
├── debug_log.h
├── led.h
├── stm32_specifics.h
├── strings.h
└── timers.h

0 directories, 8 files
```
- 例如在 `led.h` 中有如下代码：
```c
// This needs to be called before the LED can be accessed.
static inline void LedInit() {
  // Enable GPIOC.
  RCC->APB2ENR |= RCC_APB2ENR_IOPCEN;

  // Set up speed and configuration.
  const int shift = (LED_PORT - 8) * 4;
  const uint32_t old_config = GPIOC->CRH;
  const uint32_t cleared_config = (old_config & ~(0xf << shift));
  GPIOC->CRH = cleared_config | ((GPIO_MODE_OUT_2 | GPIO_CONF_GP_OD) << shift);
}
```
其中 `inline` 引起了我的关注。一般都使用库开发，其效率跟寄存器差了很远，所以
上面的这种方法特别好，在代码上实现了跟以前一样，去到一个函数初始化，但是编译后，
跟寄存器开发差不多，相当于在**解耦合和效率**之间取得了平衡。
另外一点就是需要使用 `static` 去修饰，为什么？ `static` 的作用是显式说明作用域
在本文件内，但是因为这是头文件，只要包含这个头文件， `cpp` 都会把这个头文件的
内容插到这个 `.c` 文件中去，所有这个 `static` 还有有必要的，另外一点就是 
`inline` 不是一定会被展开。**这个没搞清楚**。

## 单片机程序是怎么组成的？
![ 单片机程序是怎么组成的？
](https://github.com/geekyes/stm32_bare_lib/read_notes/mcu_program_form.svg)

## 开发工具 make gdb openocd
- 应该使用脚本，来写各种工具的加载部分，这个对每个工程都是独立的，自由度更大，
可以做到一次编译，以后就不用管的地步。

## 开发工具 renode
- 这是个什么鬼？ [renode](https://github.com/renode/renode)
