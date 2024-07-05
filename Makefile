id = dvd

$(id).zip:
	rm -rf $@ $(id).pdx
	pdc -s source $(id).pdx
	zip -9 -r $@ $(id).pdx
	
clean:
	-rm -rf $(id).zip $(id).pdx
