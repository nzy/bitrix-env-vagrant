# Vagrant box для работы в с окружением Битрикс

Машина для локальной работы с Битрикс. 

* На машину устанавливается CentOS 6.7 86x64, затем окружение Битрикс;

* Когда окружение Битрикса установлено, отключается автозагрузка ~/menu.sh для root'а;
Если нужно что-то сделать в меню окружения, нужно зайти под root'ом (логин: root, пароль:vagrant) и запустить ~/menu.sh вручную.

* Активируется XDebug;

* Создаются системные папки /tmp/php_sessions/www и /tmp/php_upload/www;

* Добавляются директивы: в /etc/httpd/bx/custom/z_bx_custom.conf `EnableSendfile Off`; в /etc/nginx/bx/conf/bitrix_general.conf `sendfile off`;

* Качается http://www.1c-bitrix.ru/download/scripts/bitrixsetup.php в /home/bitrix/www/bitrixsetup.php.

Web сервер на виртуальной машине работает на 80 порту.

## Настройка PhpStorm для работы

 * Копируем файлы bitrix-env-vagrant в проект PhpStorm;
 * Создаем сервер в PhpStorm;
 * Ставим галку Use path mappings и прописываем локальный путь к проекту, а Absolute path on server прописываем в "/home/bitrix/www";
 * Редактируем Run/Debug Configurations;
 * Создаем PHP Web Application, все настройки оставляем по-умолчанию;
 * Идем в Tools - Vagrant - Up.

PhpStorm готов к отладке PHP на виртуальной машине.
