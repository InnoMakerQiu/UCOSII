#include "main.h"
#include "OS_stk.h"
#include "stm32f401xe.h"

int a = 11;

// 写一个时钟初始化的函数，配置为HSE，PLLM为4，PLLN为84，PLLP分频为2，PLLQ分频为4，还有AHB的地方分频为1 ，得到主频为84Mhz
void RCC_Configuration(void)
{
    // 先把PLL和PLL2S disable了
    RCC->CR &= ~0x05000000;
    // 先该各个分频系数,并且选择PLLSRC，把HSE设置为PLL的输入源
    RCC->PLLCFGR = 0b00000100010000000001010100000100;   //0x4401504的二进制是：0000 0100 0100 0000 0001 0101 0000 0100
    // 上面的配置是：PLLM=4, PLLN=84, PLLP=2, PLLQ=4，并且设置HSE为PLL的输入源
    // 设置AHB的分频系数为1
    RCC->CFGR &= ~0xF0;
    // 设置APB1的分频系数为2，APB2的分频系数为1
    RCC->CFGR |= 0x1000;
    RCC->CFGR &= ~0xE000;
    // 设置启动HSE，开启PLL和PLL2S
    RCC->CR |= 0b00000101000000010000000000000000; //0x5010000
    // HSE启动成功后，使能FLASH预存取缓冲区
    FLASH->ACR |= FLASH_ACR_PRFTEN;
    // 设置FLASH的延时周期
    FLASH->ACR |= FLASH_ACR_LATENCY_2WS;
    // 更改系统的时钟源为PLL
    RCC->CFGR |= 0x00000002;
    // 关闭HSI
    RCC->CR &= ~0x00000001;
}

int main()
{
    // 时钟初始化
    RCC_Configuration();
    OSInit();
    // 创建一个自己的任务
    (void)OSTaskCreate(my_task_0_t_, (void *)0, &my_task_0[MY_TASK_SIZE_0-1u], 20);
    // OS启动
    OSStart();
    return 0;
}

void my_task_0_t_(void* args)
{
    (void)OSTaskCreate(my_task_1_t_, (void *)0, &my_task_1[MY_TASK_SIZE_1-1u], 10);
    while (1)
    {
        a = 10;
    }
}

void my_task_1_t_(void* args)
{
    while (1)
    {
        a = 11;
    }
}