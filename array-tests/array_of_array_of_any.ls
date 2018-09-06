######
#This test checks that types with no subtyping relations
#result in array of Any.
#in this example, we will use classes A and string.
######
#EXPECTED OUTPUT:
#arr1 type is [Any]
#arrA type is [A]
#arrStr type is [string]
#arr2 type is [[Any]]
######

class A

a1 = new A
str1 = 'str1'
str2 = 'str2'

arr1 = [a1,str1,str2]

arrA = [a1]
arrStr = [str1,str2]
arr2 = [arrA,arrStr]