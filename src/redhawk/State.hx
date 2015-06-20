package redhawk;

enum State<TValue> {
  Pending;
  Fulfilled(value : TValue);
  Rejected(error : Reason);
}
