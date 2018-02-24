class A extends int
class B extends A
class C extends A

A2B = (a) ->
	b = new B
	b = someBFunction(a)

bee = (b_1, b_2) ->
	A2B(b_1 + b_2)

AandC = (a,c) ->
	bb = A2B(c)
	d = new C
	d = A2B(bb)

a = new A
b1 = A2B(a)	
b2 = A2B(a)
bee(b1,b2)
c1 = new C
cc = AandC(b1,c1)

