# ML Kit finds its components by reflection when the process starts, and R8's
# full mode (the AGP 9 default) removes the no-argument constructors they are
# instantiated through. Without this the app starts but every decode fails
# with "getClass() on a null object reference".
-keep class com.google.mlkit.**.internal.*Registrar { <init>(); }
