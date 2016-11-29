import std.file : read, readText, mkdirRecurse;
import std.path : buildPath;
import std.string : splitLines, toStringz;
import std.range : lockstep;
import std.format : format;

import derelict.freeimage.freeimage;

enum LABEL_BYTE_SIZE = 1;
enum IMAGE_SIZE = 32;
enum IMAGE_PIXEL_COUNT = IMAGE_SIZE * IMAGE_SIZE;
enum IMAGE_BYTE_SIZE = IMAGE_PIXEL_COUNT * 3;
enum ENTRY_BYTE_SIZE = LABEL_BYTE_SIZE * 2 + IMAGE_BYTE_SIZE;

void main(string[] args) {
    assert(args.length == 2);
    auto dataDirPath = args[1];
    auto coarseLabels = dataDirPath.buildPath("coarse_label_names.txt").readText().splitLines();
    auto fineLabels = dataDirPath.buildPath("fine_label_names.txt").readText().splitLines();
    auto trainBin = dataDirPath.buildPath("train.bin").read();
    auto testBin = dataDirPath.buildPath("test.bin").read();

    auto trainImage = trainBin.decodeLabeledImages(coarseLabels, fineLabels);
    auto testImages = testBin.decodeLabeledImages(coarseLabels, fineLabels);

    DerelictFI.load();

    trainImage.saveImages(dataDirPath.buildPath("train"));
    testImages.saveImages(dataDirPath.buildPath("test"));
}

struct LabeledImage {
    struct Pixel {
        ubyte r;
        ubyte g;
        ubyte b;
    }

    Pixel[1024] pixels;
    string coarseLabel;
    string fineLabel;
}

LabeledImage[] decodeLabeledImages(void[] batchBin, string[] coarseLabels, string[] fineLabels) {
    auto batchBytes = cast(byte[]) batchBin;
    assert (batchBytes.length % ENTRY_BYTE_SIZE == 0);
    auto images = new LabeledImage[batchBytes.length / ENTRY_BYTE_SIZE];

    foreach (i; 0 .. images.length) {
        auto coarseLabel = coarseLabels[batchBytes[0]];
        auto fineLabel = fineLabels[batchBytes[1]];
        batchBytes = batchBytes[2 .. $];

        auto redComponents = batchBytes[0 .. IMAGE_PIXEL_COUNT];
        batchBytes = batchBytes[IMAGE_PIXEL_COUNT .. $];
        auto greenComponents = batchBytes[0 .. IMAGE_PIXEL_COUNT];
        batchBytes = batchBytes[IMAGE_PIXEL_COUNT .. $];
        auto blueComponents = batchBytes[0 .. IMAGE_PIXEL_COUNT];
        batchBytes = batchBytes[IMAGE_PIXEL_COUNT .. $];

        auto image = &images[i];
        image.coarseLabel = coarseLabel;
        image.fineLabel = fineLabel;
        foreach (j, r, g, b; lockstep(redComponents, greenComponents, blueComponents)) {
            image.pixels[j] = LabeledImage.Pixel(r, g, b);
        }
    }

    return images;
}

void saveImages(LabeledImage[] images, string rootPath) {
    size_t[string] countDirPaths;
    foreach (i; 0 .. images.length) {
        auto image = &images[i];

        auto dirPath = rootPath.buildPath(image.coarseLabel, image.fineLabel);
        dirPath.mkdirRecurse();

        auto index = countDirPaths.get(dirPath, 0);
        saveImage(image, dirPath, index);
        countDirPaths[dirPath]++;
    }
}

void saveImage(LabeledImage* image, string dirPath, size_t index) {
    auto bitmap = FreeImage_Allocate(IMAGE_SIZE, IMAGE_SIZE, 32,
            FI_RGBA_RED_MASK, FI_RGBA_GREEN_MASK, FI_RGBA_BLUE_MASK);

    auto pixelSize = FreeImage_GetLine(bitmap) / IMAGE_SIZE;

    foreach (y; 0 .. IMAGE_SIZE) {
        auto line = FreeImage_GetScanLine(bitmap, y);

        foreach (x; 0 .. IMAGE_SIZE) {
            auto pixel = image.pixels[x + (IMAGE_SIZE - 1 - y) * IMAGE_SIZE];
            line[FI_RGBA_RED] = pixel.r;
            line[FI_RGBA_GREEN] = pixel.g;
            line[FI_RGBA_BLUE] = pixel.b;
            line[FI_RGBA_ALPHA] = BYTE.max;
            line += pixelSize;
        }
    }

    auto imageName = format("%s:%s:%d.png", image.coarseLabel, image.fineLabel, index);
    assert (FreeImage_Save(FIF_PNG, bitmap, dirPath.buildPath(imageName).toStringz()));

    FreeImage_Unload(bitmap);
}
