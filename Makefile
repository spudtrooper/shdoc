NAME=shdoc

all: .phony

test: $(NAME).rb .functions
	chmod +x $<
	ruby ./$^

bootstrap: $(NAME).rb .$(NAME)
	chmod +x $<
	ruby $^

clean:
	rm -f `find . -name "*~"`
	rm -rf man