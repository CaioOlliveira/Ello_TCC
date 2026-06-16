export class AppError extends Error {
  constructor(
    public readonly codigo: string,
    public readonly mensagem: string,
    public readonly statusCode = 400,
  ) {
    super(mensagem);
  }
}
