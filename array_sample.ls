class A
class B extends A

foo = (a) -> 
	if a
		return new A
	else
		return new B

a1 = new A
a2 = new A

arr = [[a1],[a2]]
arr2 = [2]
arr[0] = arr2
