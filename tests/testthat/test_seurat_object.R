# Tests for functions dependent on a seurat object
set.seed(42)

# load a minimal example data set (subset of nbt dataset)
load("../testdata/nbt_small.Rdata")
nbt.small <- log(nbt.small + 1)


# Test Initial Normalization
expect_equal(LogNormalize(matrix(1:16, nrow = 4))[1,1], 6.908755, tolerance = 1e-6)

# Tests for object creation (via new/Setup)
# --------------------------------------------------------------------------------
context("Object creation")

# Generate Seurat object
min.cells <- 3
project.name <- "nbt.test"
names.field <- 2
names.delim <- "_"
min.genes <- 1000
expression.thresh <- 1

nbt.test <- new("seurat", raw.data = nbt.small)

test_that("object initialization creates seurat object", {
  expect_is(nbt.test, "seurat")
})

nbt.test <- Setup(nbt.test, project = project.name, min.cells = min.cells, names.field = names.field,
                  names.delim = names.delim, min.genes = min.genes, is.expr = expression.thresh, do.logNormalize = F)

test_that("entered parameters set correctly", {
  expect_match(project.name, nbt.test@project.name)
  expect_equal(expression.thresh, nbt.test@is.expr)
})

test_that("correct cells are used",{
  gene.count <- unname(findNGene(nbt.test@raw.data, nbt.test@is.expr))
  expect_equal(min(gene.count), 2405)
  expect_true(all(gene.count >= min.genes))
})

test_that("correct genes are used", {
  useable.genes <- rowSums(nbt.test@raw.data > expression.thresh)
  useable.genes <- useable.genes[useable.genes >= min.cells]
  used.genes <- rownames(nbt.test@data)

  expect_true(length(useable.genes) > 0)
  expect_equal(length(useable.genes), length(used.genes))
})

test_that("names and IDs set correctly", {
  expect_true(length(colnames(nbt.test@raw.data)) > 0)
  expect_equal(nbt.test@cell.names, colnames(nbt.test@raw.data))

  expected.cluster.ids = c("GW21.2", "GW16", "GW21")
  expect_equal(as.vector(unique(nbt.test@ident)), expected.cluster.ids)
  expect_equal(as.vector(unique(nbt.test@ident)), as.vector(unique(nbt.test@data.info$orig.ident)))

})

test_that("scaling done correctly", {
  expect_equal(nbt.test@scale.data["AACS", "Hi_GW21.2_3"], 1.66900902464456)
  expect_equal(nbt.test@scale.data["ZYX", "Hi_GW16_1"], -0.658326175185112)
})

test_that("nGene calculations are consistent" , {
  gene.count <- unname(findNGene(nbt.test@raw.data, nbt.test@is.expr))
  expect_equal(nbt.test@mix.probs[, 1], gene.count)
  expect_equal(nbt.test@gene.scores[, 1], gene.count)

})


# Test PCA dimensional reduction
# --------------------------------------------------------------------------------
context("PCA dimensional reduction")

nbt.test <- MeanVarPlot(nbt.test, y.cutoff = 2,x.low.cutoff = 2,fxn.x = expMean,fxn.y = logVarDivMean)
pcs.compute <- 4
nbt.test <- PCAFast(nbt.test, pcs.compute = pcs.compute, do.print = FALSE)

test_that("PCAFast returns expected data", {
  expect_equal(abs(nbt.test@pca.rot[1,1]), 0.1442809, tolerance = 1e-6)
  expect_equal(abs(nbt.test@pca.x[1,1]), 0.4362582, tolerance = 1e-6)
  expect_equal(ncol(nbt.test@pca.x), pcs.compute)
  expect_equal(ncol(nbt.test@pca.rot), pcs.compute)
  
})

nbt.test <- PCA(nbt.test, do.print = FALSE)
test_that("PCA returns expected data", {
  expect_true(nrow(nbt.test@pca.rot) == ncol(nbt.test@data))
  expect_true(nrow(nbt.test@pca.x) == length(nbt.test@var.genes))
  expect_equal(nbt.test@pca.rot[1,1], -0.8723915, tolerance = 1e-6)
  expect_equal(nbt.test@pca.x[1,1], 0.4362582, tolerance = 1e-6 )
})

# Tests for tSNE
# --------------------------------------------------------------------------------
context("tSNE")
nbt.test <- RunTSNE(nbt.test, dims.use = 1:2, do.fast = T, perplexity = 4)

test_that("tSNE is run correctly", {
  expect_equal(nrow(nbt.test@tsne.rot), ncol(nbt.test@data))
  expect_equal(nbt.test@tsne.rot[1,1], 12.118800, tolerance = 1e-6)
})

test_that("tSNE plots correctly", {
  p <- TSNEPlot(nbt.test)
  expect_is(p, "list")
  expect_equal(length(unique(p[[1]][[1]]$group)), 3)
})

# Tests for plotting functionality (via Setup)
# --------------------------------------------------------------------------------
context("Plotting/Visualization")

test_that("Violin plots (VlnPlot() ) return as expected", {
  expect_is(VlnPlot(nbt.test, "ZYX", do.ret = T)[[1]]$layers[[1]]$geom, "GeomViolin" )
  expect_equal(length(VlnPlot(nbt.test, c("ZYX", "AACS"), do.ret = T)), 2)

})

test_that("CellPlots return as expected", {
  expect_equal(CellPlot(nbt.test, nbt.test@cell.names[1], nbt.test@cell.names[2]), NULL)
})

test_that("GenePlots return as expected", {
  expect_equal(GenePlot(nbt.test,"DLX1","DLX2"), NULL)
})

test_that("MeanVarPlot works as expected", {
  expect_is(MeanVarPlot(nbt.test, y.cutoff = 2,x.low.cutoff = 2,fxn.x = expMean,fxn.y = logVarDivMean), "seurat")
})

test_that("FeaturePlot works as expected", {
  expect_is(FeaturePlot(nbt.test, "DLX1"), "list")
  expect_is(FeaturePlot(nbt.test, c("DLX1", "nGene")), "list")
  expect_is(FeaturePlot(nbt.test, "DLX1", cols.use = "Purples"), "list")
})


# Tests for clustering related functions
# --------------------------------------------------------------------------------
context("Clustering Functions")

test_that("SNN calculations are correct and handled properly", {
  expect_true(length(nbt.test@snn.dense) == 0)
  expect_true(length(nbt.test@snn.sparse) == 0)

  nbt.test <- FindClusters(nbt.test, pc.use = 1:2, print.output = 0, k.param = 4, k.scale = 1, save.SNN = T)
  expect_true(length(nbt.test@snn.dense) > 1)
  expect_equal(nbt.test@snn.dense[2,9], 0.6)

  nbt.test <- FindClusters(nbt.test, pc.use = 1:2, print.output = 0, k.param = 4, k.scale = 1, do.sparse = T, 
                           save.SNN = T, n.iter = 1, n.start = 1 )

  expect_true(length(nbt.test@snn.dense) == 1)
  expect_true(length(nbt.test@snn.sparse) > 1)
  expect_equal(nbt.test@snn.sparse[2,9], 0.6)
  
  nbt.test <- FindClusters(nbt.test, resolution = 1, print.output = 0)
  
  expect_warning(FindClusters(nbt.test, k.param = 4, reuse.SNN = T, resolution = 1, n.iter = 1, n.start = 1, print.output = 0))
  nbt.test@snn.sparse <- sparseMatrix(1, 1, x = 1)
  nbt.test@snn.dense <- matrix()
  expect_error(FindClusters(nbt.test, resolution = 1, reuse.SNN = T))
  
})


nbt.test <- FindClusters(nbt.test, k.param = 4, resolution = seq(1,2,0.1), print.output = 0, n.iter = 1,
                         n.start = 1)

test_that("Clustering over multiple resolution values handled correctly", {
  nbt.test <- FindClusters(nbt.test, k.param = 4, resolution = seq(1,2,0.1), print.output = 0, n.iter = 1,
                           n.start = 1)
  expect_equal(length(nbt.test@data.info$res.1), ncol(nbt.test@data))
  expect_equal(length(nbt.test@data.info$res.2), ncol(nbt.test@data))
  expect_equal(length(nbt.test@snn.sparse), 1)
  expect_equal(length(nbt.test@snn.dense), 1)
})
