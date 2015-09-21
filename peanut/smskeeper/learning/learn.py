from sklearn.ensemble import RandomForestClassifier
from sklearn import cross_validation
import numpy as np
import scipy as sp
import csv
from sklearn.externals import joblib


def llfun(act, pred):
    epsilon = 1e-15
    pred = sp.maximum(epsilon, pred)
    pred = sp.minimum(1 - epsilon, pred)
    ll = sum(act * sp.log(pred) + sp.subtract(1, act) * sp.log(sp.subtract(1, pred)))
    ll = ll * -1.0 / len(act)
    return ll


def main():
    # read in  data, parse into training and target sets
    dataset = np.genfromtxt(open('output.csv', 'r'), delimiter=',')[1:]
    target = np.array([x[-1] for x in dataset])
    train = np.array([x[:-2] for x in dataset])

    # In this case we'll use a random forest, but this could be any classifier
    cfr = RandomForestClassifier(n_estimators=100)

    # Simple K-Fold cross validation. 5 folds.
    # (Note: in older scikit-learn versions the "n_folds" argument is named "k".)
    cv = cross_validation.KFold(len(train), n_folds=5, indices=False)

    # iterate through the training and test cross validation segments and
    # run the classifier on each one, aggregating the results into a list
    results = []
    for traincv, testcv in cv:
        probas = cfr.fit(train[traincv], target[traincv]).predict_proba(train[testcv])
        results.append(llfun(target[testcv], [x[1] for x in probas]))

    # print out the mean of the cross-validated results
    print "Results: " + str(np.array(results).mean())
    joblib.dump(cfr, 'smskeeper/learning/models/model')

    with open('output.csv', 'r') as csvfile:
        reader = csv.reader(csvfile, delimiter=',')
        done = False
        for row in reader:
            if not done:
                with open('smskeeper/learning/models/headers.csv', 'w') as out:
                    writer = csv.writer(out, delimiter=',')
                    writer.writerow(row)
            done = True

if __name__ == "__main__":
    main()
