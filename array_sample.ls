class A
class B extends A

foo = (a) -> 
	if a
		return new B
	else
		return new B

a1 = new B
a2 = new B
a3 = new B

arr = [a1,a2,a3]
arr[a] = foo(true)
c = arr[0]
b = a
