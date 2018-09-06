######
#This test checks that composite types subtyping
#is considered when infering the type of an array of arrays.
#in this example, we will use classes A and B
######
#EXPECTED OUTPUT:
#arrB type is [B]
#arrA type is [A]
#arr type is [[A]].
######

class A
class B extends A

b1 = new B
b2 = new B
a1 = new A

arrB = [b1,b2]
arrA = [a1]
arr = [arrA,arrB]