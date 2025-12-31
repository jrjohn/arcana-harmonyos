import { http } from '@kit.NetworkKit';
import { ApiConfig, ApiEndpoints, ApiHeaders, HttpStatus } from './ApiConfig';
import {
  PaginatedUsersResponse,
  SingleUserResponse,
  CreateUserResponseDto,
  UpdateUserResponseDto,
  UserDtoMapper
} from './dto/UserDto';
import { User, CreateUserRequest, UpdateUserRequest, PaginatedUsers } from '../../domain/models/User';
import { Result, ResultFactory } from '../../domain/models/Result';
import { AppError, AppErrorFactory } from '../../domain/models/AppError';
import { Logger } from '../../core/logging/Logger';

const TAG = 'UserApiService';

/**
 * API service for user-related network operations.
 * Handles all HTTP communication with the reqres.in API.
 */
export class UserApiService {
  private httpRequest: http.HttpRequest;

  constructor() {
    this.httpRequest = http.createHttp();
  }

  /**
   * Fetches paginated users from the API
   */
  async getUsers(page: number = 1): Promise<Result<PaginatedUsers, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.USERS}?page=${page}`;
    Logger.d(TAG, `Fetching users from: ${url}`);

    try {
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as PaginatedUsersResponse;
        Logger.d(TAG, `Successfully fetched ${data.data.length} users`);
        return ResultFactory.success(UserDtoMapper.toPaginatedDomain(data));
      } else {
        Logger.e(TAG, `API error: ${response.responseCode}`);
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      Logger.e(TAG, `Network error fetching users: ${error}`);
      return ResultFactory.failure(this.handleError(error));
    }
  }

  /**
   * Fetches a single user by ID
   */
  async getUserById(userId: number): Promise<Result<User, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.userById(userId)}`;
    Logger.d(TAG, `Fetching user ${userId} from: ${url}`);

    try {
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as SingleUserResponse;
        Logger.d(TAG, `Successfully fetched user: ${data.data.email}`);
        return ResultFactory.success(UserDtoMapper.toDomain(data.data));
      } else if (response.responseCode === HttpStatus.NOT_FOUND) {
        Logger.w(TAG, `User ${userId} not found`);
        return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${userId}`));
      } else {
        Logger.e(TAG, `API error: ${response.responseCode}`);
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      Logger.e(TAG, `Network error fetching user: ${error}`);
      return ResultFactory.failure(this.handleError(error));
    }
  }

  /**
   * Creates a new user
   */
  async createUser(request: CreateUserRequest): Promise<Result<User, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.USERS}`;
    const body = UserDtoMapper.toCreateDto(request);
    Logger.d(TAG, `Creating user at: ${url}`);

    try {
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: this.getHeaders(),
        extraData: JSON.stringify(body),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.CREATED || response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as CreateUserResponseDto;
        Logger.d(TAG, `Successfully created user with ID: ${data.id}`);
        return ResultFactory.success(UserDtoMapper.createResponseToDomain(data, request));
      } else {
        Logger.e(TAG, `API error creating user: ${response.responseCode}`);
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      Logger.e(TAG, `Network error creating user: ${error}`);
      return ResultFactory.failure(this.handleError(error));
    }
  }

  /**
   * Updates an existing user
   */
  async updateUser(request: UpdateUserRequest): Promise<Result<User, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.userById(request.id)}`;
    const body = UserDtoMapper.toUpdateDto(request);
    Logger.d(TAG, `Updating user ${request.id} at: ${url}`);

    try {
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.PUT,
        header: this.getHeaders(),
        extraData: JSON.stringify(body),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as UpdateUserResponseDto;
        Logger.d(TAG, `Successfully updated user ${request.id}`);
        return ResultFactory.success(UserDtoMapper.updateResponseToDomain(data, request));
      } else if (response.responseCode === HttpStatus.NOT_FOUND) {
        Logger.w(TAG, `User ${request.id} not found for update`);
        return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${request.id}`));
      } else {
        Logger.e(TAG, `API error updating user: ${response.responseCode}`);
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      Logger.e(TAG, `Network error updating user: ${error}`);
      return ResultFactory.failure(this.handleError(error));
    }
  }

  /**
   * Deletes a user
   */
  async deleteUser(userId: number): Promise<Result<void, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.userById(userId)}`;
    Logger.d(TAG, `Deleting user ${userId} at: ${url}`);

    try {
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.DELETE,
        header: this.getHeaders(),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.NO_CONTENT || response.responseCode === HttpStatus.OK) {
        Logger.d(TAG, `Successfully deleted user ${userId}`);
        return ResultFactory.success(undefined);
      } else if (response.responseCode === HttpStatus.NOT_FOUND) {
        Logger.w(TAG, `User ${userId} not found for deletion`);
        return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${userId}`));
      } else {
        Logger.e(TAG, `API error deleting user: ${response.responseCode}`);
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      Logger.e(TAG, `Network error deleting user: ${error}`);
      return ResultFactory.failure(this.handleError(error));
    }
  }

  /**
   * Cleanup resources
   */
  destroy(): void {
    this.httpRequest.destroy();
  }

  /**
   * Gets standard headers for API requests
   */
  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Content-Type'] = ApiHeaders.CONTENT_TYPE;
    headers['Accept'] = ApiHeaders.ACCEPT;
    headers['x-api-key'] = ApiConfig.API_KEY;
    return headers;
  }

  /**
   * Handles network errors and converts them to AppError
   */
  private handleError(error: Error | Object): AppError {
    if (error instanceof Error) {
      const message = error.message.toLowerCase();
      if (message.includes('timeout')) {
        return AppErrorFactory.networkTimeout();
      } else if (message.includes('network') || message.includes('connection')) {
        return AppErrorFactory.noConnection();
      }
      return AppErrorFactory.networkError(error.message, error);
    }
    return AppErrorFactory.unknown();
  }
}
