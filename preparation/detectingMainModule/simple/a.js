// Task: Catch when a program is ran as main or a module and act accordingly if module don’t run something, etc

if (require.main === module) {
  console.log("I'm parent/main module");
} else {
  console.log("I'm child/child module/loaded module");
}