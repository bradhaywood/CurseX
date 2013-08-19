use strict;
use warnings;
use inc::Module::Install 0.91;

name 'App-CurseX';
all_from 'lib/App/CurseX.pm';

requires 'Moo';
requires 'Curses::UI';
requires 'Sysadm::Install';
resources repository => 'https://github.com/bradhaywood/CurseX.git'; 

if ($Module::Install::AUTHOR) {
    system("pod2text lib/App/CurseX.pm > README")
        and die $!;
}

install_script 'bin/cursex';
WriteAll();
