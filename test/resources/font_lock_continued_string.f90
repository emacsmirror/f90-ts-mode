 ! copy from the test corpus of the fortran tree-sitter grammar
!^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ font-lock-comment-face
 program test
!^^^^^^^ font-lock-keyword-face
!        ^^^^ font-lock-function-name-face
  print*, "12&bar"
! ^^^^^ font-lock-keyword-face
!      ^ nil
!       ^ f90-ts-font-lock-delimiter-face
!         ^ f90-ts-font-lock-delimiter-face
!          ^^^^^^ font-lock-string-face
!                ^ f90-ts-font-lock-delimiter-face
  print*, """"
! ^^^^^ font-lock-keyword-face
!      ^ nil
!       ^ f90-ts-font-lock-delimiter-face
!         ^ f90-ts-font-lock-delimiter-face
!          ^ f90-ts-font-lock-escape-face
!           ^ font-lock-string-face
!            ^ f90-ts-font-lock-delimiter-face
  print*, "'"
! ^^^^^ font-lock-keyword-face
!      ^ nil
!       ^ f90-ts-font-lock-delimiter-face
!         ^ f90-ts-font-lock-delimiter-face
!          ^ font-lock-string-face
!           ^ f90-ts-font-lock-delimiter-face
  print*, "   ""   "
! ^^^^^ font-lock-keyword-face
!      ^ nil
!       ^ f90-ts-font-lock-delimiter-face
!         ^ f90-ts-font-lock-delimiter-face
!          ^^^ font-lock-string-face
!             ^ f90-ts-font-lock-escape-face
!              ^^^^ font-lock-string-face
!                  ^ f90-ts-font-lock-delimiter-face
  print*, "   &  x   "
! ^^^^^ font-lock-keyword-face
!      ^ nil
!       ^ f90-ts-font-lock-delimiter-face
!         ^ f90-ts-font-lock-delimiter-face
!          ^^^^^^^^^^ font-lock-string-face
!                    ^ f90-ts-font-lock-delimiter-face
  print*, "&
! ^^^^^ font-lock-keyword-face
!      ^ nil
!       ^ f90-ts-font-lock-delimiter-face
!         ^^ f90-ts-font-lock-delimiter-face
          &hello"
!         ^ f90-ts-font-lock-delimiter-face
!          ^^^^^ font-lock-string-face
!               ^ f90-ts-font-lock-delimiter-face
  print*, "this is "&
! ^^^^^ font-lock-keyword-face
!      ^ nil
!       ^ f90-ts-font-lock-delimiter-face
!         ^ f90-ts-font-lock-delimiter-face
!          ^^^^^^^^ font-lock-string-face
!                  ^ f90-ts-font-lock-escape-face
!                   ^ f90-ts-font-lock-delimiter-face
          &"one string"
!         ^ f90-ts-font-lock-delimiter-face
!          ^^^^^^^^^^^ font-lock-string-face
!                     ^ f90-ts-font-lock-delimiter-face
  print*, "this is"&
! ^^^^^ font-lock-keyword-face
!      ^ nil
!       ^ f90-ts-font-lock-delimiter-face
!         ^ f90-ts-font-lock-delimiter-face
!          ^^^^^^^ font-lock-string-face
!                 ^ f90-ts-font-lock-escape-face
!                  ^ f90-ts-font-lock-delimiter-face
          "one string"
!         ^^^^^^^^^^^ font-lock-string-face
!                    ^ f90-ts-font-lock-delimiter-face
  print*, "this is "&
! ^^^^^ font-lock-keyword-face
!      ^ nil
!       ^ f90-ts-font-lock-delimiter-face
!         ^ f90-ts-font-lock-delimiter-face
!          ^^^^^^^^ font-lock-string-face
!                  ^^ f90-ts-font-lock-delimiter-face
     &   // "two strings"
!    ^ f90-ts-font-lock-delimiter-face
!        ^^ f90-ts-font-lock-operator-face
!           ^ f90-ts-font-lock-delimiter-face
!            ^^^^^^^^^^^ font-lock-string-face
!                       ^ f90-ts-font-lock-delimiter-face
  print*, "this is "&
! ^^^^^ font-lock-keyword-face
!      ^ nil
!       ^ f90-ts-font-lock-delimiter-face
!         ^ f90-ts-font-lock-delimiter-face
!          ^^^^^^^^ font-lock-string-face
!                  ^^ f90-ts-font-lock-delimiter-face
         , "two strings"
!        ^ f90-ts-font-lock-delimiter-face
!          ^ f90-ts-font-lock-delimiter-face
!           ^^^^^^^^^^^ font-lock-string-face
!                      ^ f90-ts-font-lock-delimiter-face

  print*, "this is"&
! ^^^^^ font-lock-keyword-face
!      ^ nil
!       ^ f90-ts-font-lock-delimiter-face
!         ^ f90-ts-font-lock-delimiter-face
!          ^^^^^^^ font-lock-string-face
!                 ^ f90-ts-font-lock-escape-face
!                  ^ f90-ts-font-lock-delimiter-face
          &""
!         ^ f90-ts-font-lock-delimiter-face
!          ^ font-lock-string-face
!           ^ f90-ts-font-lock-delimiter-face
  print*, "this is"&
! ^^^^^ font-lock-keyword-face
!      ^ nil
!       ^ f90-ts-font-lock-delimiter-face
!         ^ f90-ts-font-lock-delimiter-face
!          ^^^^^^^ font-lock-string-face
!                 ^ f90-ts-font-lock-escape-face
!                  ^ f90-ts-font-lock-delimiter-face
          ""
!         ^ font-lock-string-face
!          ^ f90-ts-font-lock-delimiter-face

  str1 = "123&456"
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^^^^^ font-lock-string-face
!                ^ f90-ts-font-lock-delimiter-face
  str2 = "abc&
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^ font-lock-string-face
!            ^ f90-ts-font-lock-delimiter-face
         &def"
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^ font-lock-string-face
!            ^ f90-ts-font-lock-delimiter-face
  str3 = "with empty line: uvw&
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^^^^^^^^^^^^^^^^^^ font-lock-string-face
!                             ^ f90-ts-font-lock-delimiter-face

         &xyz"
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^ font-lock-string-face
!            ^ f90-ts-font-lock-delimiter-face
  str4 = "   with leading blanks: 987&
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^^^^^^^^^^^^^^^^^^^^^^^^^ font-lock-string-face
!                                    ^ f90-ts-font-lock-delimiter-face
         &   654"
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^^^^ font-lock-string-face
!               ^ f90-ts-font-lock-delimiter-face
  str5 = "with trailing blanks: 987&    
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^^^^^^^^^^^^^^^^^^^^^^^ font-lock-string-face
!                                  ^ f90-ts-font-lock-delimiter-face
!                                   ^^^^ nil
         &654  "
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^^^ font-lock-string-face
!              ^ f90-ts-font-lock-delimiter-face
  str6 = "with trailing comment which is not a comment: ijk&  ! comment"
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ font-lock-string-face
!                                                                      ^ f90-ts-font-lock-delimiter-face
  str7 = "with comment: !@#&
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^^^^^^^^^^^^^^^ font-lock-string-face
!                          ^ f90-ts-font-lock-delimiter-face
         ! comment
!        ^^^^^^^^^ font-lock-comment-face
         &$%^"
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^ font-lock-string-face
!            ^ f90-ts-font-lock-delimiter-face
  str8 = "with comments and empty lines: ###&
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ font-lock-string-face
!                                           ^ f90-ts-font-lock-delimiter-face

         ! comment
!        ^^^^^^^^^ font-lock-comment-face
         ! comment
!        ^^^^^^^^^ font-lock-comment-face

         &***"
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^ font-lock-string-face
!            ^ f90-ts-font-lock-delimiter-face
  str9 = "without second amp: def&
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^ f90-ts-font-lock-delimiter-face
!         ^^^^^^^^^^^^^^^^^^^^^^^ font-lock-string-face
!                                ^ f90-ts-font-lock-delimiter-face
         ghi"
!        ^^^ font-lock-string-face
!           ^ f90-ts-font-lock-delimiter-face
  strA = "&
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^^ f90-ts-font-lock-delimiter-face
         &"
!        ^^ f90-ts-font-lock-delimiter-face
  strB = "&
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^^ f90-ts-font-lock-delimiter-face
         ! comment
!        ^^^^^^^^^ font-lock-comment-face
         &"
!        ^^ f90-ts-font-lock-delimiter-face
  strC = "&
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^^ f90-ts-font-lock-delimiter-face
         &9"
!        ^ f90-ts-font-lock-delimiter-face
!         ^ font-lock-string-face
!          ^ f90-ts-font-lock-delimiter-face
  strD = "0&
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^ f90-ts-font-lock-delimiter-face
!         ^ font-lock-string-face
!          ^ f90-ts-font-lock-delimiter-face
         &"
!        ^^ f90-ts-font-lock-delimiter-face
  strE = "&&
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^ f90-ts-font-lock-delimiter-face
!         ^ font-lock-string-face
!          ^ f90-ts-font-lock-delimiter-face
         &"
!        ^^ f90-ts-font-lock-delimiter-face
  strF = "&
! ^^^^ nil
!      ^ f90-ts-font-lock-operator-face
!        ^^ f90-ts-font-lock-delimiter-face
         &&"
!        ^ f90-ts-font-lock-delimiter-face
!         ^ font-lock-string-face
!          ^ f90-ts-font-lock-delimiter-face
 end program test
!^^^ font-lock-keyword-face
!    ^^^^^^^ font-lock-keyword-face
!            ^^^^ font-lock-function-name-face
