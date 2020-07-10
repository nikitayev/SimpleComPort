# SimpleComPort
blocking simple pascal/delphi serial port component/class

Самая простая реализация для работы блокирующего обмена с COM портом используя WinAPI

Компоненты в основном работают хорошо, но на некоторых кривых железках типа PL-2303HXA (http://www.prolific.com.tw/US/ShowProduct.aspx?p_id=225&pcid=41) нормально работать отказывается - зависает и даже вываливается в синий экран смерти.
Рекомендую использовать компоненты Synapse:
http://svn.code.sf.net/p/synalist/code/trunk
или
https://github.com/nikitayev/synapse/
для работы с COM-портом в режиме блокировки, либо AsyncPro для работы без блокировок: https://github.com/TurboPack/AsyncPro.git/
