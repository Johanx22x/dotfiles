import json
 

def get_colorscheme():
    f = open("/home/johan/.cache/wal/colors.json")
      
    data = json.load(f)
      
    f.close()

    return data


class Colors:
    def __init__(self, **kwargs):
        self.white = "#ffffff"
        self.black = "#000000"
        for k, v in kwargs.items():
            setattr(self, k, v)


def get_colors():
    data = get_colorscheme()
    return Colors(**{**data["special"], **data["colors"]})


if __name__ == "__main__":
    print(get_colors().__dict__)
