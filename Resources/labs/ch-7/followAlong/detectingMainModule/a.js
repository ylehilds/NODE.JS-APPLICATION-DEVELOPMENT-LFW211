if (require.main === module) {
  console.log("I'm parent/main module");
} else {
  console.log("I'm child/child module/loaded module");
}