def encrypt_file(input_path, user, output_path=None):
    if output_path is None:
        output_path = input_path

    fernet = user.get_fernet()

    with open(input_path, "rb") as f:
        data = f.read()
    encrypted = fernet.encrypt(data)

    with open(output_path, "wb") as f:
        f.write(encrypted)


def decrypt_file(input_path, user, output_path=None):
    if output_path is None:
        output_path = input_path

    fernet = user.get_fernet()

    with open(input_path, "rb") as f:
        data = f.read()
    decrypted = fernet.decrypt(data)

    with open(output_path, "wb") as f:
        f.write(decrypted)
