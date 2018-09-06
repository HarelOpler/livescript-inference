######
#This test checks that primitive types subtyping
#is considered when infering the type of array of array.
######
#EXPECTED OUTPUT:
#arrOfInt type is [[int]]
#arrOfFloat type is [[float]].
######

arrOfInt = [[1,2],[1,2]]
arrOfFloat = [[1,2],[1.0,2]]
