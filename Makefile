# Makefile for all the examples in the STM32 Bare Library.

# Override this if you want to store temporary files outside of the source folder.
GENDIR := ./gen/

# Sub-directories holding generated files.
OBJDIR := $(GENDIR)/obj/
ELFDIR := $(GENDIR)/elf/
BINDIR := $(GENDIR)/bin/
DEPDIR := $(GENDIR)/dep/

# The cross-compilation toolchain prefix to use for gcc binaries.
CROSS_PREFIX := arm-none-eabi
AS := $(CROSS_PREFIX)-as
CC := $(CROSS_PREFIX)-gcc
CPP := $(CROSS_PREFIX)-g++
LD := $(CROSS_PREFIX)-gcc
OBJCOPY := $(CROSS_PREFIX)-objcopy

OPTFLAGS := -O3
# Debug symbols are enabled with -g, but since we compile ELFs down to bin files, these don't
# affect the code size on-device.
# -std=gnu99 --> 一直以来， C 就分成 ANSI C 和 gun C ， 据说是历史原因哦！
# -gdwarf-2 --> 生成 dwarf version 2 的调试信息
# = 是最基本的赋值
# := 是覆盖之前的值
# ?= 是如果没有被赋值过就赋予等号后面的值
# += 是添加等号后面的值
BASE_COMPILER_FLAGS := -mcpu=cortex-m3 -mthumb -std=gnu99 -g -gdwarf-2 $(OPTFLAGS)
CCFLAGS:= $(BASE_COMPILER_FLAGS)
CPPFLAGS:= $(BASE_COMPILER_FLAGS)

# Used to rebuild when headers used by a source file change.
# 生成 .c 文件的依赖 
# 参照： https://blog.csdn.net/linuxandroidwince/article/details/75221300
DEPFLAGS = -MT $@ -MMD -MP -MF $(DEPDIR)/$*.Td

# We rely on headers from Arm's CMSIS library for things like device register layouts. To
# download the library, use `git clone https://github.com/ARM-software/CMSIS_5` in the parent
# folder of the one this Makefile is in (not this folder, but the one above).
# echo $$? --> $? 是一个 shell # 的变量，返回上一步执行任务是否成功，用两个，是
# 因为 $ 是 make 的关键字。
CMSIS_DIR :=../CMSIS_5/
ifeq ($(shell test -d $(CMSIS_DIR) ; echo $$?), 1)
  $(error "CMSIS not found at '$(CMSIS_DIR)' - try 'git clone https://github.com/ARM-software/CMSIS_5 $(CMSIS_DIR)'")
endif

# Allow CMSIS core headers, and ones from this library.
# 头文件目录
INCLUDES := \
-isystem$(CMSIS_DIR)/CMSIS/Core/Include/ \
-I./include 

# as 即汇编器的命令行参数
ASFLAGS :=

# Defines the offsets used when linking binaries for the STM32.
# ld 链接器的命令行参数
# -T stm32_linker_layout.lds --> 链接脚本，目前理解就是一个内存的一个地图
# -Wl,参数 --> 表示这是在链接阶段才会使用的参数。
# -Wl,-Map=gen/$(TARGET).map,--cref --> 生成 map 文件，并交叉声明表输出 (--cref)
#     到 map 文件中。交叉声明表就是符号和库文件的对应关系。 
# -Wl,--gc-sections --> 链接器去掉不需要的段 (section) ，这个目前自己解释不清楚
LDFLAGS := -T stm32_linker_layout.lds  -Wl,-Map=gen/$(TARGET).map,--cref -Wl,--gc-sections

# Use this to do libc
# -specs rdimon.specs --> 不知道什么意思，只知道还有一个 nosys.specs ，表示不链
#     接跟操作系统相关的函数，比如 main 函数的 return 0; 就会链接 _exit(); 如果
#     有这个，就不会去连接库的 _exit()
# -lc --> 标准 C 库
# -lm --> 数学库
# -lrdimon --> 基本的标准 C 库，相当于精简版 -lc
# -mfloat-abi=soft or hard or softfp --> 指定怎么处理浮点数的运算
# LDFLAGS += -specs rdimon.specs -lc -lm -lrdimon -mfloat-abi=soft



# Library source files.
# The order of boot.s is important, since it needs to be first in linking
# order, since it has to be at the start of flash memory when the chip is reset
# wildcard --> 扩展通配符，在 makefile 变量的定义和函数引用中通配符会失效，所以
# addprefix --> 添加固定前缀
# patsubst --> 替换通配符
# notdir --> 去除路径
# dir --> 取目录，从文件序列中取出目录部分
LIBRARY_SRCS := \
$(wildcard source/*.c)
LIBRARY_OBJS := $(addprefix $(OBJDIR), \
$(patsubst %.c,%.o,$(patsubst %.s,%.o,$(LIBRARY_SRCS))))

EXAMPLES_FOLDERS := $(wildcard examples/*)
EXAMPLES_NAMES := $(notdir $(EXAMPLES_FOLDERS))
EXAMPLES_BINS := $(patsubst %, $(BINDIR)/examples/%.bin, $(EXAMPLES_NAMES))

# Rule used when no target is specified.
all: $(EXAMPLES_BINS)

clean:
	rm -rf $(GENDIR)

# Generic rules for generating different file types.
$(OBJDIR)%.o: %.c
	@mkdir -p $(dir $@)
	@mkdir -p $(dir $(DEPDIR)$*)
	$(CC) $(CCFLAGS) $(INCLUDES) $(DEPFLAGS) -c $< -o $@
	@mv -f $(DEPDIR)/$*.Td $(DEPDIR)/$*.d

$(OBJDIR)%.o: %.cc
	@mkdir -p $(dir $@)
	@mkdir -p $(dir $(DEPDIR)$*)
	$(CPP) $(CPPFLAGS) $(INCLUDES) $(DEPFLAGS) -c $< -o $@
	@mv -f $(DEPDIR)/$*.Td $(DEPDIR)/$*.d

$(OBJDIR)%.o: %.s
	@mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) $< -o $@

$(BINDIR)/%.bin: $(ELFDIR)/%.elf
	@mkdir -p $(dir $@)
	$(OBJCOPY) $< $@ -O binary

# Loop through all of the example folders and create a rule to build each .elf
# file automatically.
# 跟 C 语言的宏定义一样的概念
define BUILD_EXAMPLE_ELF
$(1): $(2)
	@mkdir -p $(dir $(1))
	$(LD) $(LDFLAGS) -o $(1) $(2)
endef

# foreach --> 
#     $(foreach <var>,<list>,<text>)
#     这个函数的意思是，把参数 <list> 中的单词逐一取出放到参数 <var> 所指定的变
#     量中，然后再执行 <text> 所包含的表达式。每一次 <text> 会返回一个字符串，
#     循环过程中， <text> 所返回的每个字符串会以空格分隔，最后当整个循环结束时，
#     <text> 所返回的每个字符串所组成的整个字符串（以空格分隔）
#     将会是 foreach 函数的返回值。
# eval --> makefile 不会对宏函数中的 $() 做展开，只是简单的替换，这个就可以对
#     宏函数返回字符串中的 $() 再展开
$(foreach name,$(EXAMPLES_NAMES),\
$(eval $(call BUILD_EXAMPLE_ELF,\
$(ELFDIR)/examples/$(name).elf,\
$(LIBRARY_OBJS) $(patsubst %.c,$(OBJDIR)%.o,$(wildcard examples/$(name)/*.c)))))

# Include dependency tracking rules.
# .PRECIOUS: --> 再这个后面声明的中间文件不会被删除
# basename --> 取前缀函数，这个跟 dir 不一样，只是去到了文件名后面的后缀
# $(DEPDIR)/%.d: ; --> 建立一个没有依赖的目标，; 我猜是为了与伪目标做区别吧。
$(DEPDIR)/%.d: ;
.PRECIOUS: $(DEPDIR)/%.d
ALL_SRCS := \
$(wildcard examples/*/*.c) \
$(wildcard source/*.c)
-include $(patsubst %,$(DEPDIR)/%.d,$(basename $(ALL_SRCS)))
