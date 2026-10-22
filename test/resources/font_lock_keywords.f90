 non_recursive subroutine non_rec()
!^^^^^^^^^^^^^ font-lock-keyword-face
!              ^^^^^^^^^^ font-lock-keyword-face
!                         ^^^^^^^ font-lock-function-name-face
!                                ^^ f90-ts-font-lock-bracket-face
 end subroutine non_rec
!^^^ font-lock-keyword-face
!    ^^^^^^^^^^ font-lock-keyword-face
!               ^^^^^^^ font-lock-function-name-face

 recursive subroutine rec()
!^^^^^^^^^ font-lock-keyword-face
!          ^^^^^^^^^^ font-lock-keyword-face
!                     ^^^ font-lock-function-name-face
!                        ^^ f90-ts-font-lock-bracket-face
 end subroutine rec
!^^^ font-lock-keyword-face
!    ^^^^^^^^^^ font-lock-keyword-face
!               ^^^ font-lock-function-name-face
