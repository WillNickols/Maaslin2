for (R_file in dir(getwd(), pattern = "*.R$")) {
    source(file.path(getwd(), R_file))
}

# taxa <- read.csv("Blueberry_genus_table.tsv", skip = 1, sep="\t")
# metadata <- read.csv("Blueberry_metadata.tsv", sep="\t")

x <- Maaslin2(list("input_data" = taxa, "input_metadata" = metadata, "output" = "output", min_abundance = 0.1, min_prevalence = 0.02, min_variance = 0.01, max_significance = 0.2, normalization = "CSS"))
y <- Maaslin2::Maaslin2("input_data" = taxa, "input_metadata" = metadata, "output" = "output", min_abundance = 0.1, min_prevalence = 0.02, min_variance = 0.01, max_significance = 0.2, normalization = "CSS")

sum(x$fitted == y$fitted, na.rm=T)
sum(x$fitted != y$fitted, na.rm=T)

packrat:::recursivePackageDependencies("Maaslin2", ignore = "", lib.loc = .libPaths()[1])
packrat:::recursivePackageDependencies("Maaslin2Lite", ignore = "", lib.loc = .libPaths()[1])
