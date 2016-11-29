This is a program to expand the CIFAR-100 data set binaries into PNG images, organized in directories by label.

You'll need a D compiler and DUB to run this:

    dub run -- <CIFAR-100 directory>

The CIFAR-100 directory should contain:

    coarse_label_names.txt
    fine_label_names.txt
    test.bin
    train.bin

Images are organized in with the format ` <CIFAR-100 directory>/<train|test>/<coarse label>/<fine label>/<coarse label>:<fine label>:<index>.png`.

The output is placed in the folders `train` and `test` in the same directory.
