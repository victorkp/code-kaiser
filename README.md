## Future Work ##
  - Convolutional Neural Network for static code analysis
    - or Recurrent Neural Network

[Predicting Source Code Quality with Static Analysis and ML](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=3&ved=0ahUKEwjYrIKbprXPAhUPS2MKHbEgBjIQFgg_MAI&url=http%3A%2F%2Fojs.bibsys.no%2Findex.php%2FNIK%2Farticle%2Fdownload%2F26%2F22&usg=AFQjCNEK84A3gdc1tR8zsWDBWOsFmdJ8rA&sig2=dtwAidz2cDR5pM-I8rUqtg&bvm=bv.134052249,d.cGc&cad=rja)

[Static Code Features for a ML Based Inspection](https://www.diva-portal.org/smash/get/diva2:829833/FULLTEXT01.pdf)

[Convolutional Neural Networks for NLP](http://www.wildml.com/2015/11/understanding-convolutional-neural-networks-for-nlp/)

Detection Goals (in Java, for now):
  - Code is unreadable (maybe not enough comments?)
  - Subroutine is too long
  - Subroutine has duplicate structure to another
  - Presence of `TODO`
  - Exceptions caught but not acted upon?
  - Dangerous use of reflection
  - Confusing/non-distinct naming?
  - Not checking for null arguments (unless @NonNull)
  - Thread doesn't handle interruption (`InterruptedException` or `Thread.interrupted()`)
  - Stretch Goals
    - Mutual exclusion
    - Bad use of data structure
      - Searching through List
      - Iterating through Map

Thoughts on feature extraction
  - Keep some kind of possible call tree?
    - Perhaps generate call tree from a testing class

