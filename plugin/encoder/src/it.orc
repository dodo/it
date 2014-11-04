
.init orc0_init


.function orc0_foobar
.dest   1 d uint8_t
.source 1 s uint8_t

#subb d s 128
#andb d s 0x80
shrsb d s 1


.function orc0_reverse_order_u16
.dest   2 d uint16_t
.source 2 s uint16_t
.temp   1 _lb
.temp   1 _rb

splitwb   _lb _rb s
mergebw d _lb _rb   # reversed order


.function orc0_reverse_order_u32
.dest   4 d uint32_t
.source 4 s uint32_t
.temp   1 _lb
.temp   1 _rb
.temp   2 _lw
.temp   2 _rw

splitlw   _lw _rw s

splitwb     _lb _rb _lw
mergebw _lw _lb _rb     # reversed order

splitwb     _lb _rb _rw
mergebw _rw _lb _rb     # reversed order

mergewl d _lw _rw

