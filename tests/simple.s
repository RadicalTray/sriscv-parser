.code
        add     x2,x0,x0   ; i = 0
        add     x3,x0,x0   ; s = 0
        add     x4,x0,10   ; x4 = 10
L5:
        bge     x2,x4,L4   ; i >= 10 exit
        add     x3,x3,x2   ; s += i
        add     x2,x2,1    ; i++
        beq     x0,x0,L5
L4:                           ; result in x3
.end
