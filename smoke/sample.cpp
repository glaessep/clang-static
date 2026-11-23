int apply(int x) {
  return x + 1;
}
double apply(double x) {
  return x * 2.0;
}
int callInt() {
  return apply(1);
}
double callDouble() {
  return apply(2.0);
}
