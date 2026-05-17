R = QQ[x_0..x_6]/(x_0+x_1)
M = coker vars R

Myfun = M -> (
    C := res(M, LengthLimit => 5);
    for i from 0 to length C list (
	a := i + 1;
	res i;
	r := rank C_i;
	r + a
	)
    )

end--
restart

needs "demo.m2"
errorDepth = 3 -- error in demo.m2
Myfun M

errorDepth = 2 -- error in Complexes
Myfun M

errorDepth = 1 -- error in Core
Myfun M

errorDepth = 0 -- error in startup.m2??
Myfun M

-- seeing the syntax tree
pseudocode Myfun

-- profiling
profile Myfun M

-- seeing the result
profileSummary

-- the inner data
debug Core
ProfileTable
