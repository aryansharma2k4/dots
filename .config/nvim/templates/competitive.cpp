// $(PROBLEM)

#include <bits/stdc++.h>
using namespace std;

using ll  = long long;
using pii = pair<int, int>;
using vi  = vector<int>;

#define all(x)  (x).begin(), (x).end()
#define rall(x) (x).rbegin(), (x).rend()
#define sz(x)   (int)(x).size()

// Prints anything to stderr, tagged with the expression that produced it.
// stderr is not judged, so this can stay in the submitted file.
#ifdef LOCAL
#define dbg(...) cerr << "[" << #__VA_ARGS__ << "] = ", dbg_out(__VA_ARGS__)
template <class T> void dbg_out(const T &x) { cerr << x << '\n'; }
template <class T, class... R> void dbg_out(const T &x, const R &...r) {
  cerr << x << ", "; dbg_out(r...);
}
#else
#define dbg(...)
#endif

void solve() {

}

int main() {
  // Unties cin from cout and from the C streams. Worth roughly an order of
  // magnitude on input-heavy problems; the cost is that printf/scanf and
  // interactive flushing must not be mixed in after this point.
  ios::sync_with_stdio(false);
  cin.tie(nullptr);

  int t = 1;
  // cin >> t;          // uncomment for multi-testcase problems
  while (t--) solve();
  return 0;
}
