#include <iostream>
#include <fstream>
#include <vector>
#include <sstream>

using namespace std;

vector<int> parseLineToVector(const string& line) {
	vector<int> result;
	stringstream ss(line);
	string token;
	while (getline(ss, token, ',')) {
    	result.push_back(stoi(token));
	}
	return result;
}

bool isSafeState(int processes, int resources,
             	const vector<int>& available,
             	const vector<vector<int>>& allocation,
             	const vector<vector<int>>& need,
             	vector<int>& safeSequence) {

	vector<bool> finish(processes, false);
	vector<int> work = available;
	safeSequence.clear();

	while (safeSequence.size() < processes) {
    	bool allocated = false;
    	for (int i = 0; i < processes; ++i) {
        	if (!finish[i]) {
            	bool canAllocate = true;
            	for (int j = 0; j < resources; ++j) {
                	if (need[i][j] > work[j]) {
                    	canAllocate = false;
                    	break;
                	}
            	}

            	if (canAllocate) {
                	for (int j = 0; j < resources; ++j) {
                    	work[j] += allocation[i][j];
                	}
                	finish[i] = true;
                	safeSequence.push_back(i);
                	allocated = true;
                	break;
            	}
        	}
    	}

    	if (!allocated) {
        	return false; // No allocation was possible
    	}
	}

	return true;
}

int main() {
	ifstream infile("bank.dat");
	if (!infile) {
    	cerr << "Error: Cannot open file bank.dat" << endl;
    	return 1;
	}

	int resources, processes;
	infile >> resources >> processes;
	infile.ignore(); // Skip newline

	string line;
	getline(infile, line);
	vector<int> maxResources = parseLineToVector(line);

	vector<vector<int>> requirement(processes, vector<int>(resources));
	vector<vector<int>> allocation(processes, vector<int>(resources));

	// Read Requirement matrix
	for (int i = 0; i < processes; ++i) {
    	getline(infile, line);
    	requirement[i] = parseLineToVector(line);
	}

	// Read Allocation matrix
	for (int i = 0; i < processes; ++i) {
    	getline(infile, line);
    	allocation[i] = parseLineToVector(line);
	}

	infile.close();

	// Calculate Available
	vector<int> available = maxResources;
	for (int j = 0; j < resources; ++j) {
    	int allocated = 0;
    	for (int i = 0; i < processes; ++i) {
        	allocated += allocation[i][j];
    	}
    	available[j] -= allocated;
	}

	// Calculate Need = Requirement - Allocation
	vector<vector<int>> need(processes, vector<int>(resources));
	for (int i = 0; i < processes; ++i) {
    	for (int j = 0; j < resources; ++j) {
        	need[i][j] = requirement[i][j] - allocation[i][j];
    	}
	}

	// Check for safe state
	vector<int> safeSequence;
	if (isSafeState(processes, resources, available, allocation, need, safeSequence)) {
    	cout << "Safe" << endl;
    	cout << "Safe sequence: ";
    	for (size_t i = 0; i < safeSequence.size(); ++i) {
        	cout << "P" << safeSequence[i];
        	if (i != safeSequence.size() - 1)
            	cout << " -> ";
    	}
    	cout << endl;
	} else {
    	cout << "Unsafe" << endl;
	}

	return 0;
}

/* 
(Safe)
3 5
10,5,7
7,5,3
3,2,2
9,0,2
2,2,2
4,3,3
0,1,0
2,0,0
3,0,2
2,1,1
0,0,2

(Unsafe)
3 5
7,2,6
6,4,3
3,2,2
9,0,2
2,2,2
4,3,3
0,1,0
2,0,0
3,0,2
2,1,1
0,0,2

*/

