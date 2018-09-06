######
#This test checks that a variable used as array index
#is infered as an integer.
######
#EXPECTED OUTPUT:
#-i type is int.
#-arr type is [float].
#-a type is float.
######

arr = [1,2,3.0]
a = arr[i]

