######
#This test checks that primitive types subtyping
#is considered when infering the type of the array,
#even when items altering the infered type are added after initilization.
#in this example, we will use int and float.
######
#EXPECTED OUTPUT:
#arrOfFloat type is [float].
######

arrOfFloat = [1,0] ##currently array type is int
arrOfFloat[2] = 2.4 ##this line changes array type to float

