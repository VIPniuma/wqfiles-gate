//
//  DoroHardeningConfig.h
//  Doro工具箱 加固参数（全部外置，改这里即可，不要写死在逻辑里）。
//
#ifndef DoroHardeningConfig_h
#define DoroHardeningConfig_h

// 字符串混淆密钥（单字节）。gen_string_table.py 从本行读取，必须与运行时解密一致。
// 改动本值后必须重跑 tools/wqfiles_gate_hardener/gen_string_table.py 重新生成 DoroStringTable.h。
#define DORO_CRYPT_KEY 0xA7

// 反调试总开关（1 开 / 0 关）。排障时可临时置 0 重编。
#define DORO_ANTI_DEBUG_ENABLED 1
// ptrace(PT_DENY_ATTACH)：阻止 gdb/LLDB/frida-server 附加。
#define DORO_DENY_ATTACH 1
// 检测 DYLD_INSERT_LIBRARIES 等注入环境变量与 Frida 默认端口。
#define DORO_ANTI_INJECT 1

#endif
