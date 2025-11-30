// buddy_system.cpp
// Compile: g++ -std=c++17 buddy_system.cpp -o buddy_system


#include <bits/stdc++.h>
using namespace std;


struct Request {
    int id, arrival, req_size, rounded_size, duration;
};


struct Allocation {
    int id, addr, order, alloc_size, req_size, free_time;
};


int next_power_of_two(int x) {
    if (x <= 1) return 1;
    int p = 1;
    while (p < x) p <<= 1;
    return p;
}


int nearest_pow2(int x) {
    if (x <= 1) return 1;
    int lo = 1;
    while (lo * 2 <= x) lo <<= 1;
    int hi = lo * 2;
    if (abs(x - lo) == abs(hi - x)) return hi;
    return (abs(x - lo) < abs(hi - x)) ? lo : hi;
}


class BuddySystem {
public:
    BuddySystem(int mem) {
        total_mem = next_power_of_two(mem);
        N = 0;
        while ((1 << N) < total_mem) N++;
        free_lists.assign(N + 1, set<int>());
        free_lists[N].insert(0);
        total_free = total_mem;
        total_internal = 0;
    }


    bool allocate(int req_id, int rounded_size, int req_size, int now, Allocation &out) {
        int k = order_of(rounded_size);
        if (k < 0 || k > N) return false;


        int j = k;
        while (j <= N && free_lists[j].empty()) j++;
        if (j > N) return false;


        int addr = *free_lists[j].begin();
        free_lists[j].erase(free_lists[j].begin());


        while (j > k) {
            j--;
            int buddy_addr = addr + (1 << j);
            free_lists[j].insert(buddy_addr);
        }


        out.id = req_id;
        out.addr = addr;
        out.order = k;
        out.alloc_size = (1 << k);
        out.req_size = req_size;
        out.free_time = now;


        total_free -= out.alloc_size;
        total_internal += (out.alloc_size - req_size);
        return true;
    }


    void free_block(const Allocation &a) {
        int addr = a.addr, k = a.order;
        int curAddr = addr, curOrder = k;
        while (curOrder < N) {
            int buddy = curAddr ^ (1 << curOrder);
            auto it = free_lists[curOrder].find(buddy);
            if (it == free_lists[curOrder].end()) break;
            free_lists[curOrder].erase(it);
            curAddr = min(curAddr, buddy);
            curOrder++;
        }
        free_lists[curOrder].insert(curAddr);
        total_free += a.alloc_size;
    }


    double internal_frag() const {
        return 100.0 * double(total_internal) / total_mem;
    }


    double external_frag() const {
        int largest = largest_free();
        int ext = total_free - largest;
        return 100.0 * double(ext) / total_mem;
    }


    int get_total_mem() const { return total_mem; }


private:
    int total_mem, N;
    vector<set<int>> free_lists;
    int total_free;
    long long total_internal;


    int order_of(int size) const {
        if (size <= 0) return -1;
        int k = 0, v = 1;
        while (v < size) { v <<= 1; k++; }
        return (v == size) ? k : -1;
    }


    int largest_free() const {
        for (int k = N; k >= 0; --k) {
            if (!free_lists[k].empty()) return (1 << k);
        }
        return 0;
    }
};


struct DeallocEvt { int time, alloc_id; };


int main() {
    ifstream fin("alloc.dat");
    if (!fin) { cerr << "alloc.dat not found\n"; return 1; }


    int mem;
    fin >> mem;
    vector<Request> reqs;
    int t, s, d;
    while (fin >> t >> s >> d) {
        if (t == -1 && s == -1 && d == -1) break;
        Request r;
        r.id = reqs.size() + 1;
        r.arrival = t;
        r.req_size = s;
        r.rounded_size = nearest_pow2(max(1, s));
        r.duration = d;
        reqs.push_back(r);
    }
    fin.close();


    BuddySystem sim(mem);
    int total_mem = sim.get_total_mem();


    auto cmp = [](auto &a, auto &b){ return a.time > b.time; };
    priority_queue<DeallocEvt, vector<DeallocEvt>, decltype(cmp)> deallocs(cmp);
    unordered_map<int, Allocation> alloc_map;
    deque<int> pending;


    vector<int> order(reqs.size());
    iota(order.begin(), order.end(), 0);
    sort(order.begin(), order.end(), [&](int a, int b){
        return reqs[a].arrival < reqs[b].arrival;
    });


    int successes = 0, processed = 0;
    int now = reqs.empty()?0:reqs[0].arrival;
    size_t arr_ptr = 0;


    while (arr_ptr < order.size() || !deallocs.empty()) {
        int next_arr = (arr_ptr < order.size()?reqs[order[arr_ptr]].arrival:INT_MAX);
        int next_dealloc = (!deallocs.empty()?deallocs.top().time:INT_MAX);


        if (next_dealloc <= next_arr) {
            now = next_dealloc;
            while (!deallocs.empty() && deallocs.top().time == now) {
                int id = deallocs.top().alloc_id;
                deallocs.pop();
                if (alloc_map.count(id)) {
                    sim.free_block(alloc_map[id]);
                    alloc_map.erase(id);
                }
                bool allocated = true;
                while (allocated && !pending.empty()) {
                    int idx = pending.front();
                    Allocation a;
                    if (sim.allocate(reqs[idx].id, reqs[idx].rounded_size, reqs[idx].req_size, now, a)) {
                        pending.pop_front();
                        a.free_time = now + reqs[idx].duration;
                        alloc_map[a.id] = a;
                        deallocs.push({a.free_time, a.id});
                        successes++;
                        allocated = true;
                    } else allocated = false;
                }
            }
        } else {
            now = next_arr;
            while (arr_ptr < order.size() && reqs[order[arr_ptr]].arrival == now) {
                int idx = order[arr_ptr++];
                processed++;
                Allocation a;
                if (reqs[idx].rounded_size > total_mem) {
                    // impossible request
                } else if (sim.allocate(reqs[idx].id, reqs[idx].rounded_size, reqs[idx].req_size, now, a)) {
                    a.free_time = now + reqs[idx].duration;
                    alloc_map[a.id] = a;
                    deallocs.push({a.free_time, a.id});
                    successes++;
                } else {
                    pending.push_back(idx);
                }
                if (processed % 10 == 0) {
                    cout << "After " << processed << " requests:\n";
                    cout << fixed << setprecision(2);
                    cout << " Success% = " << (100.0*successes/processed) << "\n";
                    cout << " Internal fragmentation% = " << sim.internal_frag() << "\n";
                    cout << " External fragmentation% = " << sim.external_frag() << "\n";
                }
            }
        }
    }


    cout << "\nSimulation complete.\n";
    cout << "Total requests: " << reqs.size() << "\n";
    cout << "Successful: " << successes << "\n";
    cout << "Failed: " << (reqs.size()-successes) << "\n";
    cout << fixed << setprecision(2);
    cout << "Final Internal fragmentation% = " << sim.internal_frag() << "\n";
    cout << "Final External fragmentation% = " << sim.external_frag() << "\n";
}
