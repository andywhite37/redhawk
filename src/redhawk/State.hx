package redhawk;

enum State<TValue> {
  Pending;
  Fulfilled(value : TValue);
  Rejected(reason : Reason);
}
