
options:
	grep "^[a-z]" Makefile | cut -f1 -d:

dist-test:
	cd ../mod_ip && make -f Makefile.dist dist-test
	cd ../extras && make dist-test
	cd ../source && make dist-test 
	test -f Makefile.gigo && make -f Makefile.gigo test
	
dist-stable:
	svn update
	cd ../mod_ip && make -f Makefile.dist dist-stable
	cd ../extras && make dist-stable
	cd ../source && make all dist-stable 
	test -f Makefile.gigo && make -f Makefile.gigo stable

dist-stable-content:
	svn update
	cd ../source && make all dist-stable 
	test -f Makefile.gigo && make -f Makefile.gigo stable

justme:
	svn update
	cd ../source && make all
	test -f Makefile.gigo && make -f Makefile.gigo justme
	
