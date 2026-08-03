 subroutine error1()
!^^^^^^^^^^ font-lock-keyword-face
!           ^^^^^^ font-lock-function-name-face
!                 ^^ f90-ts-font-lock-bracket-face
      x: if (cond) then
!     ^ nil
!      ^ f90-ts-font-lock-delimiter-face
!        ^^ font-lock-keyword-face
!           ^ f90-ts-font-lock-bracket-face
!            ^^^^ nil
!                ^ f90-ts-font-lock-bracket-face
!                  ^^^^ font-lock-keyword-face
      end i x
!     ^^^ font-lock-keyword-face
!         ^^^ f90-ts-font-lock-error-face
 end subroutine error1
!^^^ font-lock-keyword-face
!    ^^^^^^^^^^ font-lock-keyword-face
!               ^^^^^^ font-lock-function-name-face

 subroutine error2()
!^^^^^^^^^^ font-lock-keyword-face
!           ^^^^^^ font-lock-function-name-face
!                 ^^ f90-ts-font-lock-bracket-face
      associate(x => y)
!     ^^^^^^^^^ font-lock-keyword-face
!              ^ f90-ts-font-lock-bracket-face
!               ^ nil
!                 ^^ f90-ts-font-lock-delimiter-face
!                    ^ nil
!                     ^ f90-ts-font-lock-bracket-face
      end asociate
!     ^^^ font-lock-keyword-face
!         ^^^^^^^^ f90-ts-font-lock-error-face
 end subroutine error2
!^^^ font-lock-keyword-face
!    ^^^^^^^^^^ font-lock-keyword-face
!               ^^^^^^ font-lock-function-name-face


 subroutine error3()
!^^^^^^^^^^ (font-lock-keyword-face f90-ts-font-lock-error-face)
!          ^ (f90-ts-font-lock-error-face)
!           ^^^^^^ (font-lock-function-name-face f90-ts-font-lock-error-face)
!                 ^^ (f90-ts-font-lock-bracket-face f90-ts-font-lock-error-face)
      x = x + y
!^^^^^^^ (f90-ts-font-lock-error-face)
!       ^ (f90-ts-font-lock-operator-face f90-ts-font-lock-error-face)
!        ^^^ (f90-ts-font-lock-error-face)
!           ^ (f90-ts-font-lock-operator-face f90-ts-font-lock-error-face)
!            ^^ (f90-ts-font-lock-error-face)
      call foo()
!^^^^^ (f90-ts-font-lock-error-face)
!     ^^^^ (font-lock-keyword-face f90-ts-font-lock-error-face)
!         ^ (f90-ts-font-lock-error-face)
!          ^^^ (font-lock-function-name-face f90-ts-font-lock-error-face)
!             ^^ (f90-ts-font-lock-bracket-face f90-ts-font-lock-error-face)
      call bar(
!^^^^^ (f90-ts-font-lock-error-face)
!     ^^^^ (font-lock-keyword-face f90-ts-font-lock-error-face)
!         ^^^^ (f90-ts-font-lock-error-face)
!             ^ (f90-ts-font-lock-bracket-face f90-ts-font-lock-error-face)
