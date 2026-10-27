.PHONY: test install_plasmoid

# The QML_XHR_ALLOW_FILE_READ is what it looks like: it tells QML to permit
# JavaScript code to read local files where it would otherwise not (or warn
# about it). This is just to read /proc/stat to provide a built-in CPU sensors.
# In a real application you'd do this in C++ and just feel the result into the
# QML environment instead.
test:
	QML_XHR_ALLOW_FILE_READ=1 qmlscene -I . --desktop --multisample --apptype gui test.qml

install_plasmoid:
	kpackagetool5 -t Plasma/Applet -u plasmoid
