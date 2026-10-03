/// Whether this build can open a picture off the device.
///
/// False here. Reading a file is easy on a phone and choosing one is not:
/// the chooser is a platform plugin, and the backdrop screen says the option
/// is web-only rather than drawing a button that opens nothing.
bool get canPickImage => false;

Future<String?> pickImage() async => null;
