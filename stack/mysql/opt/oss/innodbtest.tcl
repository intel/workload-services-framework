#!/bin/tclsh
proc runtimer { seconds } {
set x 0
set timerstop 0
while {!$timerstop} {
incr x
after 1000
if { ![ expr {$x % 60} ] } {
set y [ expr $x / 60 ]
puts "Timer: $y minutes elapsed"
}
update
if { [ vucomplete ] || $x eq $seconds } { set timerstop 1 }
}
return
}
puts "SETTING CONFIGURATION"
dbset db mysql
diset connection mysql_host 127.0.0.1
diset connection mysql_port 3306
diset tpcc mysql_driver timed
diset tpcc mysql_rampup 1
diset tpcc mysql_duration 2
loadscript
vudestroy
puts "SEQUENCE STARTED"
#foreach z { 1 2 4 8 16 24 32 40 48 56 64 72 80 88} {
foreach z { 1 88} {
puts "$z VU TEST"
vuset vu $z
vucreate
vurun
runtimer 240
vudestroy
after 20000
}
puts "TEST SEQUENCE COMPLETE"
