test_code:
        rmb 0, $a0
        rmb 1, $a1
        rmb 2, $a2
        rmb 3, $a3
        rmb 4, $a4
        rmb 5, $a5
        rmb 6, $a6
        rmb 7, $a7
        smb 0, $b0
        smb 1, $b1
        smb 2, $b2
        smb 3, $b3
        smb 4, $b4
        smb 5, $b5
        smb 6, $b6
        smb 7, $b7
        bbr 0,$a0, exit_here
        bbr 1,$a1, exit_here
        bbr 2,$a2, exit_here
        bbr 3,$a3, exit_here
        bbr 4,$a4, exit_here
        bbr 5,$a5, exit_here
        bbr 6,$a6, exit_here
        bbr 7,$a7, exit_here
        bbs 0,$b0, exit_here
        bbs 1,$b1, exit_here
        bbs 2,$b2, exit_here
        bbs 3,$b3, exit_here
        bbs 4,$b4, exit_here
        bbs 5,$b5, exit_here
        bbs 6,$b6, exit_here
        bbs 7,$b7, exit_here


exit_here:
        rts
